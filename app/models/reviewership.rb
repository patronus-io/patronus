class Reviewership < ActiveRecord::Base
  belongs_to :user
  belongs_to :repo

  accepts_nested_attributes_for :repo
end
