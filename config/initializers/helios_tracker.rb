HeliosTracker.configure do |config|
  # -----------------------------------------------------------------------
  # User Configuration
  # -----------------------------------------------------------------------

  # The name of your User model class
  config.user_class_name = "User"

  # A lambda that returns users to expose via GET /api/all_users.json
  # Receives (query_start, params) — query_start is a YYYY-MM-DD string.
  # Must return an ActiveRecord relation.
  config.user_scope = ->(query_start, params) {
    User.where.not(email: "")
        .where("updated_at > ?", query_start)
  }

  # Map API response field names to your model's attributes or lambdas.
  # :email is required by the Helios API. All other fields are optional —
  # simply remove any lines you don't need.
  config.user_fields = {
    email:                      :email,
    created_at:                 :created_at,
    # source_ip:                :source_ip,
    # first_unconfirmed_visit_id: :first_unconfirmed_visit_id,
    # login_attempt_count:      :login_attempt_count,
    # login_count:              :login_count,
    # accounts_owned_count:     ->(user) { user.accounts_owned_count },
    # free_accounts_count:      ->(user) { user.free_accounts_count },
    # unsubscribe_nonce:        :unsubscribe_nonce,
    # app_open_days_count:      :app_open_days_count,
  }

  # -----------------------------------------------------------------------
  # Visit Configuration (requires Universal Track Manager)
  # -----------------------------------------------------------------------

  # A lambda that returns visits to expose via GET /api/all_visits.json
  # Visits with a nil hmid are skipped by Helios, so filter them out here.
  config.visit_scope = ->(query_start, params) {
    UniversalTrackManager::Visit.where.not(hmid: nil)
        .where("updated_at > ?", query_start)
  }

  # Map API response field names to your visit model's attributes or lambdas.
  # :hmid is required by the Helios API.
  config.visit_fields = {
    hmid: :hmid,
    # visited_download_page: ->(visit) { visit.visited_download_page? },
  }


end
