class ConversationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @conversations = Conversation.for_user(current_user)
                                 .includes(:participant_1, :participant_2, :property)
                                 .order(updated_at: :desc)
  end

  def show
    @conversation = Conversation.for_user(current_user).find(params[:id])
    @messages = @conversation.messages.includes(:user).order(created_at: :asc)

    # Mark unread messages from the other participant as read
    @conversation.messages.where.not(user: current_user).unread.find_each(&:mark_as_read!)
  end

  def create
    other_user = User.find(params[:recipient_id])
    property = Property.find(params[:property_id])

    @conversation = Conversation.find_or_create_by!(
      participant_1: [current_user, other_user].min_by(&:id),
      participant_2: [current_user, other_user].max_by(&:id),
      property: property
    )

    # Create initial message if provided
    if params[:message].present? && params[:message][:body].present?
      @conversation.messages.create!(user: current_user, body: params[:message][:body])
    end

    redirect_to @conversation
  end
end
