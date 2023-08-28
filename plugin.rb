# frozen_string_literal: true

# name: discourse-signatures-staff
# about: Adds signatures to Discourse posts
# version: 2.1.1
# author: Rafael Silva <xfalcox@gmail.com> and Boris Tronquoy
# url: https://github.com/btronquo/discourse-signatures-staff.git
# transpile_js: true

enabled_site_setting :signatures_enabled

DiscoursePluginRegistry.serialized_current_user_fields << "see_signatures"
DiscoursePluginRegistry.serialized_current_user_fields << "signature_url"
DiscoursePluginRegistry.serialized_current_user_fields << "signature_raw"

after_initialize do
  User.register_custom_field_type("see_signatures", :boolean)
  User.register_custom_field_type("signature_url", :text)
  User.register_custom_field_type("signature_raw", :text)

  # add to class and serializer to allow for default value for the setting
  # only admin and moderator can use the custom fields
  add_to_class(:user, :see_signatures) do
    if self.admin? || self.moderator?
      if custom_fields["see_signatures"] != nil
        custom_fields["see_signatures"]
      else
        SiteSetting.signatures_visible_by_default
      end
    end
  end

  add_to_serializer(:user, :see_signatures) do
    if object.admin? || object.moderator?
      object.see_signatures
    end
  end
  
  register_editable_user_custom_field %i[see_signatures signature_url signature_raw]

  allow_public_user_custom_field :signature_cooked
  allow_public_user_custom_field :signature_url

  add_to_serializer(:post, :user_signature) do
    if SiteSetting.signatures_advanced_mode
      object.user.custom_fields["signature_cooked"] if object.user
    else
      object.user.custom_fields["signature_url"] if object.user
    end
  end

  # This is the code responsible for cooking a new advanced mode sig on user update
  DiscourseEvent.on(:user_updated) do |user|
    if (user.admin? || user.moderator?) && SiteSetting.signatures_enabled? && SiteSetting.signatures_advanced_mode && user.custom_fields["signature_raw"]
      cooked_sig =
        PrettyText.cook(
          user.custom_fields["signature_raw"],
          omit_nofollow: user.has_trust_level?(TrustLevel[3]) && !SiteSetting.tl3_links_no_follow,
        )
      # avoid infinite recursion
      if cooked_sig != user.custom_fields["signature_cooked"]
        user.custom_fields["signature_cooked"] = cooked_sig
        user.save
      end
    end
  end




end

register_asset "stylesheets/common/signatures.scss"
