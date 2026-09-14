# The app's stylesheet is small (6 KB gzipped) and every page needs all of
# it, so it goes into the page rather than costing a round trip before the
# first paint. Read once outside development; the link tag stays as the
# fallback if the source cannot be found.
module InlineCssHelper
  def inline_app_css
    css = Rails.env.development? ? read_app_css : (@@app_css ||= read_app_css)
    return stylesheet_link_tag(:app) if css.nil?
    tag.style(css.html_safe) # rubocop:disable Rails/OutputSafety
  end

  private
    @@app_css = nil

    # By exact path: several gems ship an application.css of their own, and
    # the load path would hand back the first of them.
    def read_app_css
      Rails.root.join("app/assets/stylesheets/application.css").read(encoding: Encoding::UTF_8)
    rescue StandardError => e
      Rails.logger.warn("inline css: #{e.message}")
      nil
    end
end
