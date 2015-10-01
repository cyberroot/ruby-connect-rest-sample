class PagesController < ApplicationController
  skip_before_filter :verify_authenticity_token

  AUTH_CTX = ADAL::AuthenticationContext.new(
    'login.windows.net', ENV['TENANT'])
  CLIENT_CRED = ADAL::ClientCredential.new(ENV['CLIENT_ID'], ENV['CLIENT_SECRET'])
  GRAPH_RESOURCE = 'https://graph.microsoft.com'
  
  def login
    redirect_to "/auth/azureactivedirectory"
  end
  
  def authd
    # Authentication redirects here
    code = params[:code]
    
    # Used in the template
    @name = auth_hash.info.name
    @email = auth_hash.info.email
    
    # Request an access token
    result = acquire_auth_token(code, ENV['REPLY_URL'])
    
    # Associate this token to our user's session
    session[:access_token] = result.access_token
    # name -> session
    session[:name] = @name
    # email -> session
    session[:email] = @email
    
    # Debug logging
    puts "Code: #{code}"
    puts "Name: #{@name}"
    puts "Email: #{@email}"
    puts "[authd] - Access token: #{session[:access_token]}"
  end
  
  def send_mail
    puts "[send_mail] - Access token: #{session[:access_token]}"
    
    # Used in the template
    @name = session[:name]
    @email = params[:specified_email]
    @recipient = params[:specified_email]
    
    sendMailEndpoint = URI("https://graph.microsoft.com/beta/me/sendmail")
    contentType = "application/json;odata.metadata=minimal;odata.streaming=true"
    http = Net::HTTP.new(sendMailEndpoint.host, sendMailEndpoint.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    emailBody = File.read("app/assets/MailTemplate.html")
    emailBody.sub! "{given_name}", @name
    
    puts emailBody
    
    emailMessage = "{
            Message: {
            Subject: 'Welcome to Office 365 development with Ruby',
            Body: {
                ContentType: 'HTML',
                Content: '#{emailBody}'
            },
            ToRecipients: [
                {
                    EmailAddress: {
                        Address: '#{@recipient}'
                    }
                }
            ]
            },
            SaveToSentItems: true
            }"

    response = http.post(
      "/beta/me/sendmail", 
      emailMessage, 
      initheader = 
      {
        "Authorization" => "Bearer #{session[:access_token]}", 
        "Content-Type" => contentType
      }
    )
    
    puts "Code: #{response.code}"
    puts "Message: #{response.message}"
    # check the status code and if in the success range AKA (200-299) we're good
    # otherwise report an error...
    
    render "authd"
  end

  def auth_hash
    request.env['omniauth.auth']
  end
  
  def acquire_auth_token(auth_code, reply_url)
    AUTH_CTX.acquire_token_with_authorization_code(
                  auth_code,
                  reply_url,
                  CLIENT_CRED,
                  GRAPH_RESOURCE)
  end
  
  def disconnect
    reset_session
    redirect = "#{ENV['LOGOUT_ENDPOINT']}?post_logout_redirect_uri=#{ERB::Util.url_encode(root_url)}"
    puts "REDIRECT: " + redirect
    redirect_to redirect
  end
  
end
