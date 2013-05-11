#
# Cookbook Name:: opsview_client
# Provider:: default
#
# The user (username) used to access the opsview API must be of a role with 
# at least these permissions :
# * CONFIGUREHOSTS
# * CONFIGURESAVE
# * CONFIGUREVIEW
# * RELOADACCESS

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
  @current_resource.host_attributes(@new_resource.host_attributes)
  
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
    raise "Could not reach opsview at #{@new_resource.server_url} to determine the current state of this host in opsview with the filter #{filter.to_json}. #{@e}."
  end  
  Chef::Log.debug("Opsview host config fetched")
  
  res = JSON.parse(@response)
  
  case res['summary']['rows']
  when "0"
    @current_resource.data({})
  when "1"
    @current_resource.data(res['list'][0])
  else
    raise "Search yielded #{res['summary']['rows']} hosts. '#{@response.body}'"
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
    raise "Could not reach opsview at #{@new_resource.server_url} to get an authentication token. #{@e}."
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
      raise "Failed to reload Opsview. #{@e}."
    end
  else
    Chef::Log.debug("Opsview config reloaded")
  end
end

def get_ref_hash(object_type, name)
  section = 'config'
  # TODO : Consider caching the results of these lookups locally for some
  # length of time to avoid all the calls to opsview
  filter = {"-and" => 
             [
               {"name" => 
                 {
                   "=" => name
                 }
               }
             ]
           }
  begin
    @response = RestClient.get [@new_resource.server_url, section, object_type].join('/'),
      :x_opsview_username => @new_resource.username,
      :x_opsview_token => @token,
      :content_type => :json,
      :accept => :json,
      :params => {:json_filter => filter.to_json}
  rescue => @e
    raise "Could not reach opsview at #{@new_resource.server_url} to convert the #{object_type} named #{name} to a opsview ref. #{@e}."
  end
  Chef::Log.debug("get_ref_hash response to filter \"#{filter.to_json}\" : #{@response.body}")
  res = JSON.parse(@response.body)
  if res['list'].length == 0 then
    # No object found so we'll create one
    begin
      @response = RestClient.put [@new_resource.server_url, section, object_type].join('/'),
        {"name" => name}.to_json,
        :x_opsview_username => @new_resource.username,
        :x_opsview_token => @token,
        :content_type => :json,
        :accept => :json
      Chef::Log.debug("creation of #{object_type} object called #{name} : #{@response.body}")
      res = {'list' => [JSON.parse(@response.body)['object']]}
      reload
    rescue => @e
      raise "Could not reach opsview at #{@new_resource.server_url} during creation of new #{object_type} called #{name}. #{@e}."
    end
  end

  case res['list'].length
  when 0
    raise "Couldn't find the #{object_type} object called #{name} and we failed to create a new object"
  when 1
    {'ref' => ['/rest', section, object_type, res['list'][0]['id']].join('/'),
     'name' => name}
  else
    raise "Found multiple #{object_type} objects called #{name}. #{res.to_json}"
  end
end

def get_create_attributes(attributes)
  filter = {"-or" => 
               attributes.map {|x| {"name" => {"=" => x['name']}} if x.include? 'name'}.compact
           }
  begin
    @response = RestClient.get [@new_resource.server_url, 'config', 'attribute'].join('/'),
      :x_opsview_username => @new_resource.username,
      :x_opsview_token => @token,
      :content_type => :json,
      :accept => :json,
      :params => {:json_filter => filter.to_json}
  rescue => @e
    raise "Could not reach opsview at #{@new_resource.server_url} to fetch attributes with the filter #{filter.to_json}. #{@e}."
  end
  existing_attributes = JSON.parse(@response.body)['list'].map {|x| x['name']}.compact
  attributes.each do |x|
    raise "Failed to create host because a host_attribute was missing a name : #{x.to_json}" if not x.include? 'name'
    if not existing_attributes.include? x['name'] then
      begin
        @response = RestClient.put [@new_resource.server_url, 'config', 'attribute'].join('/'),
          {"name" => x["name"]}.to_json,
          :x_opsview_username => @new_resource.username,
          :x_opsview_token => @token,
          :content_type => :json,
          :accept => :json
      rescue => @e
        raise "Could not reach opsview at #{@new_resource.server_url} to create attribute #{x.to_json}. #{@e}."
      end
    end
  end 
end

def action_create
  @url_parts = [@new_resource.server_url, 'config', 'host']
  if @current_resource.data.include? 'id'
    @url_parts << @current_resource.data['id']
  end

  if @new_resource.host_attributes.length > 0 then
    get_create_attributes @new_resource.host_attributes
  end

  # We're merging the arg1-4=>nil hash in, in case the user didn't provide
  # all the args. This will prevent the comparison of old and new to giving
  # a false mismatch due to missing arguments

  @payload = {
    "name" => (node[:fqdn] or node[:hostname]),
    "ip"=> node[:ipaddress],
    "hostgroup"=> get_ref_hash('hostgroup', @new_resource.host_group),
    "hosttemplates" => @new_resource.host_templates.map {|x| get_ref_hash('hosttemplate', x)}.compact,
    "check_period" => get_ref_hash('timeperiod', @new_resource.check_period),
    "hostattributes" => @new_resource.host_attributes.map {|x| {'arg1'=>nil, 'arg2'=>nil, 'arg3'=>nil, 'arg4'=>nil}.merge(x)}.compact
  }


  Chef::Log.debug("Opsview host creation payload : #{@payload.to_json}")

  # Here we merge the @current_resource and @payload into @new_data
  # Then we compare @new_data with @current_resource to determine
  # if the merge changed anything. If it did we update opsview and
  # reload
  @new_data = @current_resource.data.merge(@payload)
  if @current_resource.data.diff(@new_data).length > 0
    Chef::Log.debug("Identified a difference in the new opsview_client config of #{@current_resource.data.diff(@new_data)}.to_json}")
    begin
      @response = RestClient.put @url_parts.join('/'),
        @payload.to_json,
        :x_opsview_username => @new_resource.username,
        :x_opsview_token => @token,
        :content_type => :json,
        :accept => :json
    rescue => @e
      raise "Could not reach opsview at #{@new_resource.server_url} during host creation. #{@e}."
    end
    Chef::Log.debug("Host added to/updated in Opsview")
    reload
    new_resource.updated_by_last_action(true)
  end
end
