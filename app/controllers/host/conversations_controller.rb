module Host
  class ConversationsController < ApplicationController
    layout "host"
    before_action :authenticate_user!
    before_action :require_host

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
      @guest = @conversation.other_participant(current_user)

      # Booking context — the guest's most relevant stay at this property
      @booking = Booking.where(property: @conversation.property, user: @guest)
                        .order(Arel.sql("check_in DESC"))
                        .first

      @conversation.messages.where.not(user: current_user).unread.find_each(&:mark_as_read!)
    end

    private

    def require_host
      unless current_user.host? || current_user.admin?
        redirect_to root_path, alert: "You must be a host to access this area."
      end
    end
  end
end
