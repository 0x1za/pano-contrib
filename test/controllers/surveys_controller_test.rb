require "test_helper"

class SurveysControllerTest < ActionDispatch::IntegrationTest
  test "surveys are for reviewers" do
    get surveys_path
    assert_redirected_to new_session_path
    sign_in_as(users(:one))
    get surveys_path
    assert_response :not_found
  end

  test "a moderator opens a survey, records residents, and closes it" do
    sign_in_as(users(:moderator))
    get new_survey_path
    assert_response :success
    assert_select "select[name='survey[target_code]'] option", 1
    assert_difference -> { Survey.count }, 1 do
      post surveys_path, params: { survey: { target_code: "LS1", goal: 3, notes: "Start at the market." } }
    end
    survey = Survey.last
    assert_equal "Kabulonga", survey.target_name
    follow_redirect!
    assert_select "h1", "Kabulonga"
    assert_select "progress[max='3'][value='0']"

    post survey_responses_path(survey), params: { survey_response: { address: "LS1 1CC 1", recognises: "true", calls_it: "Kabulonga" } }
    assert_redirected_to survey_path(survey)
    post survey_responses_path(survey), params: { survey_response: { recognises: "false", calls_it: "Ibex Hill" } }
    assert_equal 2, survey.responses.count
    get survey_path(survey)
    assert_select ".tally li", 2
    assert_select ".entries .entry", 2
    assert_select "dl.facts dd", /50%/

    post survey_responses_path(survey), params: { survey_response: { address: "LS3 1CC 9", recognises: "true" } }
    assert_match(/not a building in this gazetteer/, flash[:alert])

    patch close_survey_path(survey)
    assert survey.reload.status_closed?
    post survey_responses_path(survey), params: { survey_response: { recognises: "true" } }
    assert_response :not_found
  end
end
