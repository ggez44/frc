require 'uri'
require 'net/http'
require 'json'

require 'byebug'

API_KEY = "bUdXNYQIL7C5HYLSX966jAqfpmjbzocnaCoTdABBsOaHFAuyyid781XDRxwOrZD4"

def query(path, params = {})
  3.times do |i|
    uri = URI.parse("https://www.thebluealliance.com/api/v3/#{path}")
    uri.query = URI.encode_www_form(params)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl=true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    headers = {"X-TBA-Auth-Key" => API_KEY}
    request = Net::HTTP::Get.new(uri.request_uri, headers)
    response = http.request(request)
    return JSON.parse(response.body) if response.code == "200"
  rescue
  end

end

def initialize_team_result
  {
    "num_matches" => 0,
    "score_offense" => 0,
    "score_defense" => 0,
    "score_defense_naive" => 0,
    "auto_pieces" => 0,
    "teleop_pieces" => 0,
    "oppo_teleop_pieces" => 0,
    "total_pieces" => 0,
    "num_cones" => 0,
    "num_cubes" => 0,
    "num_top" => 0,
    "num_mid" => 0,
    "num_bot" => 0,
    "auto_mobility_and_engaged_good" => [],
    "auto_mobility_and_engaged_bad" => [],
    "auto_charge_none" => 0,
    "auto_charge_docked" => 0,
    "auto_charge_engaged" => 0,
    "endgame_charge_none" => 0,
    "endgame_charge_parked" => 0,
    "endgame_charge_docked" => 0,
    "endgame_charge_engaged" => 0,
    "auto_mobility_yes" => 0
  }
end

def get_team_percent(team_key, results, alliance_team_keys, key)
  total = 0
  alliance_team_keys.each do |team_key|
    total += results[team_key][key]
  end

  if total == 0
    return 1.to_f / alliance_team_keys.length
  end

  results[team_key][key] / total
end

def sanitize_match_results(match_key, match_results)
  if match_results["auto_pieces"] > 7
    # eg. https://www.thebluealliance.com/match/2023txfor_qm17
    #puts "WTF #{match_key} with #{match_results["auto_pieces"]} auto pieces?!"
    # just set it as some arbitrary average
    match_results["auto_pieces"] = 3
  end
  match_results
end

def skip_match(match)
  # only look at qualification matches
  #return true unless match["key"].include?("qm")
  # only look at matches that have been played
  return true if match["actual_time"].nil?

  false
end

# this is run after the regression for offensive stats are finalized
# problem with the naive score defense is it's too dependent on the opponent's offensive abilities
# e.g. a bot in a very weak regional field will have very good defensive stats in that naive system
# there is an assumption that implicit defense isn't as impactful as explicit offense
# potentially we can do an interative regression between this and process_event_iteration too
def process_event_iteration_post(event_matches, results)
  iteration_results = {}

  #expected_offense_testing_total = {}
  event_matches.each do |match|
    next if skip_match(match)

    match["alliances"].keys.each do |alliance|
      oppo_alliance = alliance == "blue" ? "red" : "blue"

      # initialize
      match["alliances"][alliance]["team_keys"].each do |team_key|
        unless iteration_results.key?(team_key)
          iteration_results[team_key] = initialize_team_result
        end

        iteration_results[team_key]["num_matches"] += 1
      end

      # first see what the opponents are expected to get on offfense
      opponent_expected_offense = {
        "score_defense" => 0,
        "oppo_teleop_pieces" => 0,
      }
      match["alliances"][oppo_alliance]["team_keys"].each do |team_key|
        opponent_expected_offense["score_defense"] += results[team_key]["score_offense"]
        opponent_expected_offense["oppo_teleop_pieces"] += results[team_key]["teleop_pieces"]
      end

      # next see what the opponents actually did.. keys are poorly name, but match what we are looking for, for convenience
      match_results = {
        "score_defense" => match["score_breakdown"][oppo_alliance]["totalPoints"].to_f - match["score_breakdown"][oppo_alliance]["foulPoints"].to_f,
        "oppo_teleop_pieces" => match["score_breakdown"][oppo_alliance]["teleopGamePieceCount"].to_f - match["score_breakdown"][oppo_alliance]["autoGamePieceCount"].to_f 
      }
        
      ["score_defense", "oppo_teleop_pieces"].each do |key|
        match["alliances"][alliance]["team_keys"].each do |team_key|
          if key == "score_defense"
            #expected_offense_testing_total[team_key] ||= {expected: 0, actual: 0}
            #expected_offense_testing_total[team_key][:expected] += opponent_expected_offense[key]
            #expected_offense_testing_total[team_key][:actual] += match_results[key]
            #puts "#{match["key"]}: #{team_key} expected offense: #{opponent_expected_offense[key]}"
          end

          # if currently i'm 4 and teammates are -2 and 1.. if the match expected is 123 and actual is 90.. diff is +33
          # team 1: 123 - (90-4) = 37 then /3 = 12.3
          # team 2: 123 - (90+2) = 31 then /3 = 10.3
          # team 3: 123 - (90-1) = 34 then /3 = 11.3
          iteration_results[team_key][key] += (opponent_expected_offense[key] - ((match_results[key] - results[team_key][key]))) / 3.0

          if ['frc2643'].include?(team_key) && key == "score_defense"
            #puts "#{match["key"]}: #{team_key} #{(opponent_expected_offense[key] - ((match_results[key] - results[team_key][key]))) / 3.0}"
          end
        end
      end
    end
  end
  #pp expected_offense_testing_total


  iteration_results.each do |team_key, team_value|
    results[team_key]["score_defense"] = team_value["score_defense"] / team_value["num_matches"]
    results[team_key]["oppo_teleop_pieces"] = team_value["oppo_teleop_pieces"] / team_value["num_matches"]
  end

  results
end

def process_event_iteration(event_matches, results)
  iteration_results = {}

  event_matches.each do |match|
    next if skip_match(match)

    # 'blue' or 'red'
    match["alliances"].keys.each do |alliance|
      oppo_alliance = alliance == "blue" ? "red" : "blue"

      # testing with perfect data, 5940 always scores 5, 971 always score 9, 3970 always scores 3, etc
      # total_pieces = 0
      # match["alliances"][alliance]["team_keys"].each do |team_key|
        # total_pieces += team_key[3].to_i
      # end

      match_results = {
        "score_offense" => match["score_breakdown"][alliance]["totalPoints"].to_f - match["score_breakdown"][alliance]["foulPoints"].to_f,
        "score_defense_naive" => match["score_breakdown"][oppo_alliance]["totalPoints"].to_f - match["score_breakdown"][oppo_alliance]["foulPoints"].to_f,
        "auto_pieces" => match["score_breakdown"][alliance]["autoGamePieceCount"].to_f,
        "total_pieces" => match["score_breakdown"][alliance]["teleopGamePieceCount"].to_f,
      }
      match_results = sanitize_match_results(match["key"], match_results)

      match["alliances"][alliance]["team_keys"].each do |team_key|
        unless iteration_results.key?(team_key)
          iteration_results[team_key] = initialize_team_result
        end

        unless results.key?(team_key) 
          results[team_key] = initialize_team_result
        end

        iteration_results[team_key]["num_matches"] += 1
      end

      ["score_offense", "score_defense_naive", "auto_pieces", "total_pieces"].each do |key|
        match["alliances"][alliance]["team_keys"].each do |team_key|
          team_percent = get_team_percent(team_key, results, match["alliances"][alliance]["team_keys"], key)

          iteration_results[team_key][key] += match_results[key] * team_percent
          #if ['frc5940'].include?(team_key) && key == "score_defense_naive"
            #puts "#{match["key"]}: #{team_key} total #{key}: #{match_results[key]} * #{team_percent} = #{match_results[key] * team_percent}"
          #end
        end
      end
    end
  end

  iteration_results.each do |team_key, team_value|
    results[team_key]["num_matches"] = team_value["num_matches"]
    results[team_key]["score_offense"] = team_value["score_offense"] / team_value["num_matches"]
    results[team_key]["score_defense_naive"] = team_value["score_defense_naive"] / team_value["num_matches"]
    results[team_key]["auto_pieces"] = team_value["auto_pieces"] / team_value["num_matches"]
    results[team_key]["total_pieces"] = team_value["total_pieces"] / team_value["num_matches"]
    results[team_key]["teleop_pieces"] = (team_value["total_pieces"] - team_value["auto_pieces"]) / team_value["num_matches"]
  end

  results
end

def check_duplicate_opponents(matches)
  opponents_by_team = {}
  teammates_by_team = {}
  matches.each do |match|
    next unless match["comp_level"] == "qm"

    match["alliances"].keys.each do |alliance|
      match["alliances"][alliance]["team_keys"].each do |team_key|
        opponents_by_team[team_key] ||= []
        opponents_by_team[team_key] += match["alliances"][alliance == "blue" ? "red" : "blue"]["team_keys"]
        teammates_by_team[team_key] ||= []
        teammates_by_team[team_key] += match["alliances"][alliance]["team_keys"] - [team_key]
      end
    end
  end

  opponents_by_team.each do |team_key, opponents|
    opponents.tally.each do |opponent, count|
      if count > 3
        teammate_count = teammates_by_team[team_key].tally[opponent] || 0
        puts "WARNING: #{team_key} faces #{opponent} #{count} times and with #{teammate_count} times"
      end
    end
  end
end

def check_auto_mobility_and_dock(matches, results)
  matches.each do |match|
    next if skip_match(match)

    match["alliances"].keys.each do |alliance|
      match["alliances"][alliance]["team_keys"].each_with_index do |team_key, idx|
        if match["score_breakdown"][alliance]["mobilityRobot#{idx+1}"] == 'No'
          results[team_key]["auto_mobility_and_engaged_bad"] << match["key"]
        elsif 
          # got mobility
          if match["score_breakdown"][alliance]["autoChargeStationRobot#{idx+1}"] == 'Docked'
              byebug if results[team_key].nil?
            if match["score_breakdown"][alliance]["autoChargeStationPoints"].to_i == 12
              results[team_key]["auto_mobility_and_engaged_good"] << match["key"]
            else
              results[team_key]["auto_mobility_and_engaged_bad"] << match["key"]
            end
          else
            # if it never docked, then we don't know anything, so skip it
          end
        end
      end
    end
  end

  results
end

def process_event(event_key)
  puts "Processing #{event_key}"

  results = {}
  event_matches = query("event/#{event_key}/matches")
  return results if event_matches.empty?

  #check_duplicate_opponents(event_matches)

  20.times do |i|
    results = process_event_iteration(event_matches, results)
  end

  20.times do |i|
    results = process_event_iteration_post(event_matches, results)
  end

  results = check_auto_mobility_and_dock(event_matches, results)

  byebug
  results
end

def merge_team_results(team_results, new_team_results)
  new_team_results.each do |team, results|
    # skip if we already have this team from a previous event
    # only track the last event each bot participated in
    next if team_results.has_key?(team)

    team_results[team] = new_team_results[team]
  end

  team_results
end

def process_all
  teams = {}

  events = query("events/2023")
  weeks = events.reject{|x| x["week"].nil?}.group_by {|event| event["week"]}
  weeks.keys.sort.reverse.each do |week|
    # start with last week
    weeks[week].each do |event|
      team_results = process_event(event["key"])
      next if team_results.empty?

      teams = merge_team_results(teams, team_results)
    end

    break if week.to_i < 3 # for testing
  end

  stored_results = {
    last_updated: Time.now,
    teams: teams
  }
  JSON.dump(stored_results, File.open("results.json", "w"))

  stored_results
end

def process_auto_mobility_and_engaged(results)
    event_teams = query("event/2023cur/teams/keys")
    #event_teams = query("event/2023cmptx/teams/keys")

    relevent_teams = results["teams"].reject{|k,v| v["auto_mobility_and_engaged_good"].length+v["auto_mobility_and_engaged_bad"].length == 0}
    relevent_teams = relevent_teams.reject{|k,v| !event_teams.include?(k)}
    relevent_teams.sort_by{|k,v| [v["auto_mobility_and_engaged_good"].length.to_f / (v["auto_mobility_and_engaged_good"].length+v["auto_mobility_and_engaged_bad"].length), (v["auto_mobility_and_engaged_good"].length+v["auto_mobility_and_engaged_bad"].length)]}
end


def display_menu(last_updated:)
  puts ""
  puts "##########################################################"
  puts "1) Re-download all events (last updated #{last_updated})"
  puts "2) Team stats"
  puts "3) Top auto game pieces"
  puts "4) Top teleop game pieces"
  puts "5) Top total game pieces "
  puts "6) Top offense score"
  puts "7) Top defense (relative to expected opponent offense)"
  puts "8) Top auto mobility and engaged"
  puts "9) Top auto mobility and engaged (for spreadsheet)"
  puts "q) quit"
  puts "##########################################################"
  puts ""
  puts "Enter choice: "
end

def handle_choice(choice, stored_results)
  team_count = stored_results["teams"].keys.count

  case choice
  when "1"
    process_all()
  when "2"
    puts "Enter team number: "
    team_key = "frc#{gets.chomp.to_i}"
    pp stored_results["teams"][team_key]
  when "3"
    stored_results["teams"].sort_by{|k,v| v["auto_pieces"]}.each_with_index do |(team, results), i|
      puts "#{team_count-i}) #{team[3..]}: #{results["auto_pieces"]}"
    end
    puts "Top auto pieces"
  when "4"
    stored_results["teams"].sort_by{|k,v| v["teleop_pieces"]}.each_with_index do |(team, results), i|
      puts "#{team_count-i}) #{team[3..]}: #{results["teleop_pieces"]}"
    end
    puts "Top teleop pieces"
  when "5"
    stored_results["teams"].sort_by{|k,v| v["total_pieces"]}.each_with_index do |(team, results), i|
      puts "#{team_count-i}) #{team[3..]}: #{results["total_pieces"]}"
    end
    puts "Top total pieces"
  when "6"
    stored_results["teams"].sort_by{|k,v| v["score_offense"]}.each_with_index do |(team, results), i|
      puts "#{team_count-i}) #{team[3..]}: #{results["score_offense"]}"
    end
    puts "Top offense score"
  when "7"
    stored_results["teams"].sort_by{|k,v| v["score_defense"]}.each_with_index do |(team, results), i|
      puts "#{team_count-i}) #{team[3..]}: #{results["score_defense"]}"
    end
    puts "Top defense (positive score is better)"
  when "8"
    teams = process_auto_mobility_and_engaged(stored_results)
    team_count = teams.count

    teams.each_with_index do |(team, results), i|
      good = results["auto_mobility_and_engaged_good"].length.to_f
      bad = results["auto_mobility_and_engaged_bad"].length.to_f
      puts "#{team_count-i}) #{team[3..]}: #{((good / (good+bad)) * 100).round}% (#{good+bad} matches)"
    end

    puts "Top auto mobility and engaged %"
  when "9"
    teams = process_auto_mobility_and_engaged(stored_results)
    teams.reverse.each_with_index do |(team, results), i|
      good = results["auto_mobility_and_engaged_good"]
      bad = results["auto_mobility_and_engaged_bad"]
      puts "#{team[3..]},#{good.length},#{bad.length},#{good.join('-')},#{bad.join('-')}"
    end
  when "q"
  else
    puts "Invalid choice"
  end
end

def run_menu
  choice = '' 
  until choice == 'q' 
    stored_results = {}
    if File.exists?("results.json")
      stored_results = File.open("results.json") { |f| JSON.load(f) }
      display_menu(last_updated: stored_results["last_updated"])
    else
      stored_results = process_all()
      display_menu(last_updated: "just now.")
    end
    choice = gets.chomp
    handle_choice(choice, stored_results)
  end
end

run_menu
#process_event("2023camb")
#process_event("2023cur")


