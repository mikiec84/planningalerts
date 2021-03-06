# frozen_string_literal: true

require "open-uri"

class Application < ApplicationRecord
  searchkick highlight: [:description],
             index_name: "pa_applications_#{ENV['STAGE']}",
             locations: [:location],
             callbacks: :async

  belongs_to :authority
  has_many :comments, dependent: :restrict_with_exception
  has_many :replies, through: :comments
  has_many :versions, -> { order(id: :desc) }, class_name: "ApplicationVersion", dependent: :restrict_with_exception, inverse_of: :application
  has_one :current_version, -> { where(current: true) }, class_name: "ApplicationVersion", inverse_of: :application

  geocoded_by :address, latitude: :lat, longitude: :lng

  validates :council_reference, presence: true
  validates :council_reference, uniqueness: { scope: :authority_id }

  scope(:with_current_version, -> { includes(:current_version).joins(:current_version) })
  scope(:in_past_week, -> { joins(:current_version).where("application_versions.date_scraped > ?", 7.days.ago) })
  scope(:recent, -> { joins(:current_version).where("application_versions.date_scraped >= ?", 14.days.ago) })

  def search_data
    # Include version data in what's indexed by searchkick
    attributes.merge(current_version&.search_data || {})
  end

  # For the benefit of will_paginate
  cattr_reader :per_page
  # rubocop:disable Style/ClassVars
  @@per_page = 100
  # rubocop:enable Style/ClassVars

  delegate :date_scraped, :info_url, :comment_url, :date_received,
           :on_notice_from, :on_notice_to, :lat, :lng, :suburb, :state,
           :postcode, :description, :address, :location,
           :official_submission_period_expired?,
           to: :current_version

  def date_scraped=(value)
    load_version_data
    @date_scraped = value
  end

  def info_url=(value)
    load_version_data
    @info_url = value
  end

  def comment_url=(value)
    load_version_data
    @comment_url = value
  end

  def date_received=(value)
    load_version_data
    @date_received = value
  end

  def on_notice_from=(value)
    load_version_data
    @on_notice_from = value
  end

  def on_notice_to=(value)
    load_version_data
    @on_notice_to = value
  end

  def lat=(value)
    load_version_data
    @lat = value
  end

  def lng=(value)
    load_version_data
    @lng = value
  end

  def suburb=(value)
    load_version_data
    @suburb = value
  end

  def state=(value)
    load_version_data
    @state = value
  end

  def postcode=(value)
    load_version_data
    @postcode = value
  end

  def description=(value)
    load_version_data
    @description = value
  end

  def address=(value)
    load_version_data
    @address = value
  end

  # Default values for what we consider nearby and recent
  def nearby_and_recent_max_distance_km
    Application.nearby_and_recent_max_distance_km
  end

  # Default values for what we consider nearby and recent
  def nearby_and_recent_max_age_months
    Application.nearby_and_recent_max_age_months
  end

  def self.nearby_and_recent_max_distance_km
    2
  end

  def self.nearby_and_recent_max_age_months
    2
  end

  # Find applications that are near the current application location and/or recently scraped
  def find_all_nearest_or_recent
    if location
      nearbys(
        nearby_and_recent_max_distance_km,
        units: :km,
        latitude: "application_versions.lat",
        longitude: "application_versions.lng"
      ).with_current_version.where("application_versions.date_scraped > ?", nearby_and_recent_max_age_months.months.ago)
    else
      []
    end
  end

  def current_councillors_for_authority
    authority.councillors.where(current: true).shuffle if authority.councillors.any?
  end

  def councillors_available_for_contact
    current_councillors_for_authority if authority.write_to_councillors_enabled?
  end
end
