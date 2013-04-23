#
# Cookbook Name:: opsview_client
# Provider:: default
#

require 'rubygems'
require 'rest_client'
require 'json'

def load_current_resource
  @current_resource = Chef::Resource::OpsviewClient.new(@new_resource.name)
  @current_resource.data(@new_resource.data)
  @current_resource.host_templates(@new_resource.host_templates)
  @current_resource.host_group(@new_resource.host_group)
  @current_resource.check_period(@new_resource.check_period)
  @current_resource.server_url(@new_resource.server_url)
  @current_resource.username(@new_resource.username)
  @current_resource.password(@new_resource.password)
  @current_resource.ipaddress(@new_resource.ipaddress)
  
  @token ||= get_token

  filter = {"-and" => 
             [
               {"ip" => 
                 {
                   "=" => @new_resource.ipaddress
                 }
               }
             ]
           }

  begin
    @response = RestClient.get [@new_resource.server_url, 'config', 'host'].join('/'),
      :x_opsview_username => @new_resource.username,
      :x_opsview_token => @token,
      :content_type => :json,
      :accept => :json,
      :params => {:json_filter => filter.to_json}
  rescue => @e
    raise "Could not reach opsview at #{@new_resource.server_url}. #{@e}. #{@e.http_body}"
  end  
  Chef::Log.debug("Opsview host config fetched")
  
  
  case JSON.parse(@response)['summary']['rows']
  when "0"
    @current_resource.data({})
  when "1"
    @current_resource.data(JSON.parse(@response)['list'][0])
  else
    raise "Search yielded #{JSON.parse(@response)['summary']['rows']} hosts. '#{@response.body}'"
  end
end

def get_token
  begin
    @response = RestClient.post [@new_resource.server_url, 'login'].join('/'),
      { 'username' => @new_resource.username,
        'password' => @new_resource.password }.to_json,
      :content_type => :json,
      :accept => :json
  rescue => @e
    raise "Could not reach opsview at #{@new_resource.server_url}. #{@e}. #{@e.http_body}"
  end    
  JSON.parse(@response.body)['token']
end

def reload
  begin
    @response = RestClient.post [@new_resource.server_url, 'reload'].join('/'),
      '',
      :x_opsview_username => @new_resource.username,
      :x_opsview_token => @token,
      :content_type => :json,
      :accept => :json
  rescue => @e
    case @e.http_code
    when 409
      Chef::Log.debug("Opsview reload already running")
    else
      raise "Failed to reload Opsview. #{@e}. #{@e.http_body}"
    end
  else
    Chef::Log.debug("Opsview config reloaded")
  end
end

def get_ref_hash(object_type, name)
  section = 'config'
  begin
    @response = RestClient.get [@new_resource.server_url, section, object_type].join('/'),
      '',
      :x_opsview_username => @new_resource.username,
      :x_opsview_token => @token,
      :content_type => :json,
      :accept => :json
  rescue => @e
    raise "Could not reach opsview at #{@new_resource.server_url}. #{@e}. #{@e.http_body}"
  end

  {'ref' => ['/rest', section, object_type, JSON.parse(@response.body)['object']['id']].join('/'),
   'name' => name}
end

def action_create
  @url_parts = [@new_resource.server_url, 'config', 'host']
  if @current_resource.data.include? 'id'
    @url_parts << @current_resource.data['id']
  end

  @payload = {
    "name" => node[:hostname],
    "ip"=> node[:ipaddress],
    "hostgroup"=> get_ref_hash('hostgroup', @new_resource.host_group),
    "hosttemplates" => @new_resource.host_templates.each do |x|
      [] << get_ref_hash('hosttemplate', x)
    end,
    "check_period" => get_ref_hash('timeperiod', @new_resource.check_period)
  }

  # Here we merge the @current_resource and @payload into @new_data
  # Then we compare @new_data with @current_resource to determine
  # if the merge changed anything. If it did we update opsview and
  # reload
  @new_data = @current_resource.data.merge(@payload)
  if @current_resource.data.diff(@new_data).length > 0
    begin
      @response = RestClient.put @url_parts.join('/'),
        @payload.to_json,
        :x_opsview_username => @new_resource.username,
        :x_opsview_token => @token,
        :content_type => :json,
        :accept => :json
    rescue => @e
      raise "Could not reach opsview at #{@new_resource.server_url}. #{@e}. #{@e.http_body}"
    end
    Chef::Log.debug("Host added to/updated in Opsview")
    reload
    new_resource.updated_by_last_action(true)
  end
end
