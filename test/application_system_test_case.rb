require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # A phone-sized viewport: contributing happens on the pavement, not at a
  # desk. Reduced motion keeps smooth scrolling from racing the driver.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 430, 932 ] do |options|
    options.add_argument("--force-prefers-reduced-motion")
  end

  private
    # JS-dispatched clicks: headless Chrome/chromedriver drops real input
    # events intermittently (see span). The full form → Turbo → redirect
    # path is still exercised.
    def tap(locator)
      execute_script("arguments[0].click()", find_button(locator))
    end
end
