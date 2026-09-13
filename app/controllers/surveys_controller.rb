# The field protocol for moderators: open a survey on a district, record
# ten residents' answers, read the report, export the fixture.
class SurveysController < ApplicationController
  before_action :require_reviewer
  before_action :require_gazetteer, only: %i[new create]

  def index
    @surveys = Survey.recent.includes(:gazetteer_version, :opened_by)
  end

  def new
    @survey = Survey.new(goal: 10)
    @districts = current_gazetteer.places.tier_district.order(:code)
  end

  def create
    district = current_gazetteer.places.tier_district.find_by(code: survey_params[:target_code])
    @survey = Survey.new(survey_params.merge(gazetteer_version: current_gazetteer, opened_by: current_user, target_name: district&.display_name))
    if @survey.save
      redirect_to survey_path(@survey), notice: t(".opened", name: @survey.display_name)
    else
      @districts = current_gazetteer.places.tier_district.order(:code)
      render :new, status: :unprocessable_content
    end
  end

  def show
    @survey = Survey.find(params[:id])
    @responses = @survey.responses.recent_first.includes(:building, :recorded_by)
    @response = @survey.responses.new
  end

  def close
    survey = Survey.find(params[:id])
    survey.close!
    redirect_to survey_path(survey), notice: t(".closed")
  end

  def fixture
    survey = Survey.find(params[:id])
    send_data FieldFixture.new(survey).to_json_file, filename: "field-#{survey.target_code}-#{survey.id.first(8)}.json", type: "application/json"
  rescue PanoApi::Error => e
    redirect_to survey_path(survey), alert: e.message
  end

  private
    def survey_params
      params.expect(survey: [ :target_code, :goal, :notes ])
    end

    def require_gazetteer
      redirect_to surveys_path, alert: t("contributions.no_gazetteer") unless current_gazetteer
    end
end
