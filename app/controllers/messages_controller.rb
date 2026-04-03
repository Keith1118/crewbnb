class MessagesController < ApplicationController
  before_action :authenticate_user!

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
