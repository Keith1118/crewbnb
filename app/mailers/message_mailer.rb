class MessageMailer < ApplicationMailer
  def new_message(message)
    @message = message
    @conversation = message.conversation
    @sender = message.user
    @recipient = @conversation.other_participant(@sender)
    @property = @conversation.property

    mail(
      to: @recipient.email,
      subject: "New message from #{@sender.first_name || @sender.email.split('@').first}"
    )
  end
end
