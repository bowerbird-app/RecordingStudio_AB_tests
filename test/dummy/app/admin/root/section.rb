# frozen_string_literal: true

module AdminScreens
  class RootSection < RecordingStudioAdmin::Section
    key "root"
    title "Admin"
    subtitle "Site administration"
    blast_radius :site

    link :ab_tests,
         text: "A/B Tests",
         url: ->(context) { context.admin_section_path("ab_tests") }
  end
end
