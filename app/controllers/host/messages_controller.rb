module Host
  class MessagesController < ApplicationController
    layout "host"
    before_action :authenticate_user!
    before_action :require_host
    rate_limit to: 30, within: 1.minute, only: :create,
               with: -> { redirect_to host_conversations_path, alert: "You're sending messages too quickly. Please slow down." }

    def create
      @conversation = Conversation.for_user(current_user).find(params[:conversation_id])
      @message = @conversation.messages.build(message_params)
      @message.user = current_user

      if @message.save
        MessageMailer.new_message(@message).deliver_later
        redirect_to host_conversation_path(@conversation)
      else
        redirect_to host_conversation_path(@conversation), alert: "Message could not be sent."
      end
    end

    private

    def message_params
      params.require(:message).permit(:body)
    end

    def require_host
      unless current_user.host? || current_user.admin?
        redirect_to root_path, alert: "You must be a host to access this area."
      end
    end
  end
end
