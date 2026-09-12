# Agree or disagree with a pending contribution, once per device and once
# per account. A vote may tip the contribution into acceptance.
class VotesController < ApplicationController
  allow_unauthenticated_access

  def create
    contribution = Contribution.kept.find(params[:contribution_id])
    vote = contribution.votes.new(stance: params[:stance], device: current_device, user: Current.user)
    if vote.save
      contribution.reconsider!
      redirect_back_or_to contribution_path(contribution), notice: t(".thanks")
    else
      redirect_back_or_to contribution_path(contribution), alert: vote.errors.full_messages.to_sentence
    end
  end
end
