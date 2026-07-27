module Admin
  class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin
    before_action :set_user, only: [ :show, :edit, :update, :destroy ]

    def index
      @pagy, @users = pagy(User.order(created_at: :desc), limit: 20)
    end

    def show
    end

    def edit
    end

    def update
      if @user.update(user_params)
        redirect_to admin_user_path(@user), notice: "User updated successfully."
      else
        render :show, status: :unprocessable_entity
      end
    end

    def destroy
      @user.destroy
      redirect_to admin_users_path, notice: "User deleted."
    end

    # Mark a guest's business as verified without a VIES lookup — for testing,
    # and for the real case where a company checks out by hand but VIES won't
    # confirm them (new registrations take weeks to appear).
    def verify_business
      @user = User.find(params[:id])
      @user.update!(business_verified_at: Time.current)

      redirect_to admin_user_path(@user), notice: "#{@user.email} is now verified to book."
    end

    # Undo the above, for a company that shouldn't have been let through.
    def unverify_business
      @user = User.find(params[:id])
      @user.update!(business_verified_at: nil)

      redirect_to admin_user_path(@user), notice: "#{@user.email} can no longer book."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def require_admin
      unless current_user.admin?
        redirect_to root_path, alert: "You must be an admin to access this area."
      end
    end

    def user_params
      params.require(:user).permit(:first_name, :last_name, :email, :phone, :bio, :role)
    end
  end
end
