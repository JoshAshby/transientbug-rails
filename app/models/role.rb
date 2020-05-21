# frozen_string_literal: true

# == Schema Information
#
# Table name: roles
#
#  id              :bigint           not null, primary key
#  description     :string
#  name            :text             not null
#  permission_keys :string           default("{}"), not null, is an Array
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_roles_on_name  (name) UNIQUE
#

Permission = Struct.new :key, :name, :description

class Role < ApplicationRecord
  PERMISSIONS = [
    Permission.new("admin.access", "Access Admin Panel", "Access to the main admin panel"),
    Permission.new("images.admin", "Admin Images", "Access to admin specific features for images"),
    Permission.new("images.create", "Create Images", ""),
    Permission.new("images.show", "View Images", ""),
    Permission.new("images.update", "Update Images", ""),
    Permission.new("images.destroy", "Delete Images", "")
  ].freeze

  PERMISSIONS_BY_KEY = PERMISSIONS.index_by(&:key).freeze

  before_validation :clean_permissions
  validates :name, presence: true, uniqueness: true
  validate :valid_permission_keys

  def permissions
    permission_keys.map do |key|
      PERMISSIONS_BY_KEY[key]
    end
  end

  def permission? key
    fail "Unknown permission_key #{ key }" unless PERMISSIONS_BY_KEY.key? key

    permission_keys.include? key
  end

  protected

  def clean_permissions
    self.permission_keys = permission_keys.reject(&:blank?)
  end

  def valid_permission_keys
    permission_keys.each do |key|
      errors.add :permission_keys, message: "permission_key #{ key } is invalid" if PERMISSIONS_BY_KEY[key].blank?
    end
  end
end
