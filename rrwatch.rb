#!/usr/bin/ruby

require 'rubygems'
require 'mysql2'
require 'active_record'
require 'uri'
require 'net/http'
require 'net/https'
require 'system_timer'
require 'logger'



#Log file
$log = Logger.new('/var/log/rrwatch.log', 3, 1048576)

#Log levels: ERROR, WARN, INFO
$log.level = Logger::WARN

#Sites to control
#ex: %w( http://example1.com https://example2.com  )
$site_addresses = %w( )

#Always available points to check if localhost has connection
$remote_check_points = %w( http://google.com http://onet.pl http://wykop.pl  )

#Powerdns database
ActiveRecord::Base.establish_connection(
    :adapter =>  'mysql2',
    :host =>    'localhost',
    :database => 'pdns',
    :username => '',
    :password => ''
)


class Record < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
end


def get_site_ip_addresses(host)
    begin
    Record.where(["(type = ? or type = ?) and name = ?", "A","AAAA", host]).select("id,name,content,ttl,prio,type")
    rescue => e
        $log.error "Error finding all records: #{e}"
        return []
    end
end

def available_hosts(host,type)
    case type
    when 'A'
        Record.where(["type = ? and name = ? and prio <> ?", "A", host, -1]).select("id").count
    when 'AAAA'
        Record.where(["type = ? and name = ? and prio <> ?", "AAAA", host, -1]).select("id").count
    end

rescue  => e
    $log.error "Error finding all records: #{e}"
    return 0
end



def check_internet
    $fails = 0
    $remote_check_points.each do |site| 
        url = URI.parse(site)
        begin
            SystemTimer.timeout_after(5) do
                make_request(url.host, url.port, url.path)
            end
        rescue Exception => e
            $log.warn "Error connecting to internet (#{url}): #{e}"
            $fails += 1
        end
    end
    if  ( ($fails * 100) / $remote_check_points.length ) > 50
        return false
    end
    return true
end

def make_request(host,port,path)
    
    http = Net::HTTP.new host, port
    if port == 443
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.use_ssl = true
    end
  
    if path.empty?
        path = '/'
    end
    
    http.start do |agent|
        agent.get(path).response.code
    end

end

def check_availability(url, ip_address)
    
    response_code =  SystemTimer.timeout_after(5) do
        make_request(ip_address.content.to_s, url.port, url.path)
    end

    #4xx and 5xx code indicate that monitored site not work properly
    if response_code.start_with?('4', '5')
        raise "Invalid response code"
    end

    $log.info "Response code for #{ip_address.content.to_s}: #{response_code}"
    make_active(ip_address) if ip_address.prio == -1

rescue Exception => e

    $log.warn "Error connecting to #{ip_address.content.to_s}: #{e}"
    if check_internet
        if ip_address.prio != -1 and available_hosts(url.host,ip_address.type) > 1
            make_inactive(ip_address) 

    else
        $log.warn "Probably network isolation, do nothing"
    end
end

def make_inactive(ip_record)
    Record.update_all("prio=-1", "name='#{ip_record.name}' and content='#{ip_record.content}'")
    $log.warn "Dectivate #{ip_record.content}"
end

def make_active(ip_record)
    Record.update_all("prio=0", "name='#{ip_record.name}' and content='#{ip_record.content}'")
    $log.warn "Activate #{ip_record.content}"
end


trap('SIGTERM') do
    $log.warn('Exit on SIGTERM')
    exit 0
end

$log.warn('Start program')
#Main loop
loop do

    $site_addresses.each do |site|
        url = URI.parse(site)
        get_site_ip_addresses(url.host).each do |ip_address|
            check_availability(url, ip_address)
        end
    end

    sleep(15)
end
