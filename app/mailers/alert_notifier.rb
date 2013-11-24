
class AlertNotifier < ActionMailer::Base
  default :from => "#{::Configuration::EMAIL_FROM_NAME} <#{::Configuration::EMAIL_FROM_ADDRESS}>"
  helper :application, :applications

  def alert(alert, applications, comments = [])
    @alert, @applications, @comments = alert, applications, comments

    @georss_url = applications_url(:format => "rss", :address => @alert.address, :radius => @alert.radius_meters)
    
    mail(:to => alert.email,
      :subject => render_to_string(:partial => "subject",
        :locals => {:applications => applications, :comments => comments, :alert => alert}).strip,
      "return-path" => ::Configuration::BOUNCE_EMAIL_ADDRESS)
  end
end
