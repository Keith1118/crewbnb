class ConversationsController < ApplicationController
  before_action :authenticate_user!
  # Hosts/admins keep the host "extranet" chrome on Messages; guests use the site layout.
  layout :resolve_layout

  def index
    @pagy, @conversations = pagy(
      Conversation.for_user(current_user)
                  .includes(:participant_1, :participant_2, :property)
                  .order(updated_at: :desc),
      limit: 20
    )
    # One grouped query for unread counts instead of a COUNT per conversation
    @unread_counts = Message.where(conversation_id: @conversations.map(&:id), read_at: nil)
                            .where.not(user_id: current_user.id)
                            .group(:conversation_id).count
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
      participant_1: [ current_user, other_user ].min_by(&:id),
      participant_2: [ current_user, other_user ].max_by(&:id),
      property: property
    )

    # Create initial message if provided
    if params[:message].present? && params[:message][:body].present?
      @conversation.messages.create!(user: current_user, body: params[:message][:body])
    end

    redirect_to @conversation
  end

  private

  def resolve_layout
    current_user&.host? || current_user&.admin? ? "host" : "application"
  end
end
