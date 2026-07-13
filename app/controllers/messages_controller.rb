class MessagesController < ApplicationController
  before_action :authenticate_user!
  rate_limit to: 30, within: 1.minute, only: :create,
             with: -> { redirect_to conversations_path, alert: "You're sending messages too quickly. Please slow down." }

  def create
    @conversation = Conversation.for_user(current_user).find(params[:conversation_id])
    @message = @conversation.messages.build(message_params)
    @message.user = current_user

    if @message.save
      MessageMailer.new_message(@message).deliver_later
      redirect_to @conversation
    else
      redirect_to @conversation, alert: "Message could not be sent."
    end
  end

  private

  def message_params
    params.require(:message).permit(:body)
  end
end
