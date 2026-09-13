# The outbox's target: a batch of contributions made offline, applied
# idempotently for this device. JSON in, one result per mutation out.
class SyncController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection only: :push

  def push
    mutations = params.fetch(:mutations, []).map(&:to_unsafe_h)
    results = SyncApplier.new(device: current_device, user: Current.user, gazetteer: current_gazetteer, mutations: mutations).call
    render json: { results: results.map(&:to_h) }
  end
end
