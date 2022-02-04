# frozen_string_literal: true

# == Schema Information
#
# Table name: tags
#
#  id         :integer          not null, primary key
#  label      :text
#  color      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_tags_on_label  (label) UNIQUE
#

class Tag < ApplicationRecord
  COLORS = [
    :red,
    :orange,
    :yellow,
    :olive,
    :green,
    :teal,
    :blue,
    :violet,
    :purple,
    :pink,
    :brown,
    :grey,
    :black
  ].freeze

  after_initialize :set_color

  validates :label, presence: true, uniqueness: true

  has_many :bookmarks_tags
  has_many :bookmarks, through: :bookmarks_tags

  def self.find_or_create_tags tags: []
    tags.map do |tag|
      next tag if tag.is_a? Tag
      next if tag.empty?

      upsert label: tag.strip
    end.compact
  end

  private

  def set_color
    self.color ||= COLORS[ label.length % COLORS.length ]
  end
end
