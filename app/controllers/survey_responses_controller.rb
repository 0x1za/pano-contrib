class SurveyResponsesController < ApplicationController
  before_action :require_reviewer

  def create
    survey = Survey.status_open.find(params[:survey_id])
    response = survey.responses.new(response_params.merge(recorded_by: current_user))
    if response.save
      redirect_to survey_path(survey), notice: t(".recorded", n: survey.responses.count, goal: survey.goal)
    else
      redirect_to survey_path(survey), alert: response.errors.full_messages.to_sentence
    end
  end

  private
    def response_params
      params.expect(survey_response: [ :address, :recognises, :calls_it, :note ])
    end
end
