class Repo < ActiveRecord::Base
  has_many :reviewerships
  has_many :users, through: :reviewerships

  def to_s
    name
  end
end
