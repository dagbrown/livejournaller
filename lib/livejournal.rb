#!/usr/bin/ruby


require "xmlrpc/client"
require "md5"
gem "hpricot"
require "hpricot"
require "yaml"

class LiveJournal
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
        @restful_ish_client = Net::HTTP.new("www.livejournal.com")
        @restful_ish_client_headers = { 
          "User-Agent"       => "RubyLJ",
          "Content-Type"     => "text/xml; charset=UTF-8",
          "Connection"       => "keep-alive"
        }
        @comment_cache_dir = "db/ljcomments"
        @comment_cache = File.join(@comment_cache_dir, "allcomments.xml")
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

    def comment_summaries start_id=0
      @restful_ish_client_headers["Cookie"] ||= sessioncookie
      unless @comments
        @restful_ish_client.start do
          response = @restful_ish_client.get("/export_comments.bml?get=comment_meta&startid=#{start_id}", @restful_ish_client_headers)
          rexml = REXML::Document.new(response.body)
          @max_comment_id = rexml.elements["//maxid"].text.to_i
          @comment_summaries = rexml.elements.each("//comment") { }.sort_by do |c|
              c.attributes["id"].to_i
          end
          @usermap = {}
          rexml.elements.each("//usermap") do |elem|
              @usermap[elem.attribute("id").value] = 
                  elem.attribute("user").value
          end
        end
      end
      @comment_summaries
    end

    def export_comments start_id=0
      @restful_ish_client_headers["Cookie"] ||= sessioncookie

      unless @comment_bodies
          if File.exists?(@comment_cache)
              @comment_bodies = File.read(@comment_cache)
          end

          @restful_ish_client.start do
              response = @restful_ish_client.get("/export_comments.bml?get=comment_body&startid=#{start_id}", @restful_ish_client_headers)
              @comment_bodies = response.body
          end
      end
      @comment_bodies
    end

    # Post an item to livejournal
    # Required fields are +subject+ and +text+
    # Optional fields date, mood, music, 
    def post subject, text, options = {}
        date = if options[:date] then
            DateTime.parse(options[:date])
        else
            DateTime.now
        end

        callhash = {
            :event => text,
            :subject => subject,
            :year => date.year,
            :mon => date.month,
            :day => date.day,
            :hour => date.hour,
            :min => date.minute,
            :lineendings => "unix",
            :props => {}
        }

        if options[:security] then
            callhash[:security]=options[:security]
        end

        {
            :mood => :current_mood,
            :music => :current_music,
            :preformatted => :opt_preformatted,
            :nocomments => :opt_nocomments,
            :picture => :picture_keyword,
            :noemail => :opt_noemail
        }.each do |option_name, lj_option_name|
            if options[:option_name] then
                callhash[:props][lj_option_name] = options[:option_name]
            end
        end

        postevent callhash
    end

    def comments
        puts "exporting comments"
        c = export_comments
        puts "parsing comment XML"
        r = REXML::Document.new c

        my_comments = r.elements.each("//comment") {}
#         my_comments = r.elements.each("//comment") {}.map do |comment|
#             puts comment.to_s
#             id = comment.attributes["id"].to_i
#             puts "doing comment #{id}"
#             cachefilename = File.join(@comment_cache_dir, "#{id}.yaml")
#             if File.exists?(cachefilename)
#                 YAML.load File.read(cachefilename)
#             else
#                 dumpme = { 
#                     :id => comment.attributes["id"].to_i,
#                     :poster => poster(comment.attributes["posterid"]),
#                     :entry_id => comment.attributes["jitemid"].to_i,
#                     :parent_id => comment.attributes["parentid"].to_i,
#                     :subject => comment.elements["//subject"].text,
#                     :body => comment.elements["//body"].text,
#                     :date => DateTime.parse(comment.elements["//date"].text)
#                 }
#                 p dumpme
# 
#                 File.open(cachefilename,"w") do |f|
#                     f.print YAML.dump(dumpme)
#                 end
#                 dumpme
#             end
#         end
    end

    def poster posterid
        comment_summaries
        @usermap[posterid.to_s]
    end
end
