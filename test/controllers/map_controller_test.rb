require "test_helper"

class MapControllerTest < ActionDispatch::IntegrationTest
  test "the map page renders with the API url for the map controller" do
    get root_path
    assert_response :success
    assert_select "[data-controller=map][data-map-api-value]"
    assert_select "dialog.welcome:not([open])", 1, "the welcome dialog is in the page for the controller to open on a first visit"
    assert_select "dialog.welcome", /Help check Lusaka's new addresses/
    assert_select "dialog.welcome a[href='/about']", "How it works"
    assert_select "dialog.modal turbo-frame#modal", 1, "the frame contribution forms load into"
    assert_select ".bar form.search input[name=q][data-map-target=query]", 1
    assert_select "ul.suggest[data-map-target=suggest]", 1
    assert_select "[data-controller=map][data-map-satellite-value*='World_Imagery']", 1
    assert_select ".bar nav a[href='/about'][data-turbo-frame=modal]", "About"
    assert_select ".bar nav a.sign-in[href='/session/new']", "Sign in"
    assert_select ".bar nav a[href='/leaderboard'][data-turbo-frame=modal]", 1
    assert_select ".bar nav a[href='/contributions'][data-turbo-frame=modal]", 1
    assert_select ".bar nav button.help"
  end

  test "styleguide renders" do
    get styleguide_path
    assert_response :success
    assert_select ".display", "LS33 9XX 17"
  end

  test "signed in, the bar shows the name and a way out" do
    sign_in_as(users(:moderator))
    get root_path
    assert_select ".bar nav a.who[href='/contributions']", "Mwila"
    assert_select ".bar nav form[action='/session'] button.icon-btn[aria-label='Sign out'] svg", 1
    assert_select ".bar nav a.sign-in", 0
    assert_select ".bar nav a[href='/contributions']", 1, "the name is the only link to contributions"
  end
end
