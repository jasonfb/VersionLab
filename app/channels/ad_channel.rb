class AdChannel < ApplicationCable::Channel
  def subscribed
    ad = find_ad
    if ad
      stream_from "ad:#{ad.id}"
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  private

  def find_ad
    client_ids = current_user.accounts
                              .joins(:clients)
                              .select("clients.id")
                              .pluck("clients.id")
    Ad.where(client_id: client_ids).find_by(id: params[:ad_id])
  end
end
