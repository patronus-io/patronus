class Repo < ActiveRecord::Base
  has_many :reviewerships
  has_many :users, through: :reviewerships
end
