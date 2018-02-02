class Doorkeeper::ApplicationPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      # return scope.where(public: true) unless user.present?
      # return scope.all if user.role? :admin

      scope.where(owner: user).order(created_at: :desc)
    end
  end

  def create?
    record.new_record?
  end

  def show?
    user&.owner_of? record
  end

  def update?
    user&.owner_of? record
  end

  def destroy?
    user&.owner_of? record
  end
end
