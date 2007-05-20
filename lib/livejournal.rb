#!/usr/bin/ruby


require "xmlrpc/client"
require "md5"
gem "hpricot"
require "hpricot"

class LJ
    private

    def get_challenge
        result = @client.call("LJ.XMLRPC.getchallenge")
        challenge = result["challenge"]
        response = MD5.md5(challenge + @password).to_s

        @paramhash["auth_challenge"] = challenge
        @paramhash["auth_response"] = response
    end

    def ljcall(ljfnname,params = {})
        get_challenge
        paramhash = @paramhash.merge Hash[*(params.map do |a,b| 
            [a.to_s,b] 
        end.flatten)]
        @client.call "LJ.XMLRPC.#{ljfnname.to_s}", paramhash
    end

    public

    def initialize(user, password, server="www.livejournal.com")
        @client = XMLRPC::Client.new server, "/interface/xmlrpc"
        @user = user
        @password = MD5.md5(password).to_s
        @paramhash = { "username" => user,
                     "auth_method" => "challenge",
                     "ver" => 1 }
        @restful_client = Net::HTTP.new("www.livejournal.com")
        @restful_client_headers = { 
          "User-Agent"       => "RubyLJ",
          "Content-Type"     => "text/xml; charset=UTF-8",
          "Connection"       => "keep-alive"
        }
    end

    attr_reader :logindetails

    def self.lj_api *meths
        meths.each do |meth|
            eval %[
                def #{meth.to_s} params = {}
                    ljcall :#{meth}, params
                end
            ]
        end
    end

    lj_api :checkfriends, :consolecommand, :editevent, :editfriendgroups,
        :editfriends, :friendof, :getdaycounts, :getevents, :getfriends,
        :getfriendgroups, :login, :postevent, :sessionexpire,
        :sessiongenerate, :syncitems

    def user_details; @user_details ||= login end
    def friendgroups; user_details["friendgroups"] end

    def all_items
        @allitems ||= syncitems :lastsync => "1970-01-01 00:00:00"
    end

    def friends; @friends ||= getfriends["friends"] end

    def item id
        ljcall :getevents, :selecttype => "one",
            :lastsync => "1970-01-01 00:00:00",
            :itemid => id
    end

    def sessioncookie
      @sessioncookie ||= sessiongenerate
      "ljsession=#{@sessioncookie["ljsession"]}"
    end

    def comments
      @restful_client_headers["Cookie"] ||= sessioncookie
      unless @comments
        @restful_client.start do
          response = @restful_client.get("/export_comments.bml?get=comment_meta&startid=0", @restful_client_headers)
          @comments = response
        end
      end
      @comments
    end
end
