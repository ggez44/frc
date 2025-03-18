require 'date'
require 'fileutils'
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

def get_event(event_key)
  cache_file_name = "cache/event_meta_cache_#{event_key}.json"
  if File.exists?(cache_file_name)
    event = File.open(cache_file_name) { |f| JSON.load(f) }
  else
    event = query("event/#{event_key}")
  end

  if is_event_cacheable(event)
    File.open(cache_file_name, "w") do |file|
      JSON.dump(event, file)
    end
  end

  return event
end

def get_event_matches(event_key)
  cache_file_name = "cache/event_matches_cache_#{event_key}.json"
  if File.exists?(cache_file_name)
    matches = File.open(cache_file_name) { |f| JSON.load(f) }
  else
    matches = query("event/#{event_key}/matches")

    event = get_event(event_key)
    if is_event_cacheable(event)
      File.open(cache_file_name, "w") do |file|
        JSON.dump(matches, file)
      end
    end
  end

  return matches
end

def is_event_cacheable(event)
  # only cache done events
  event_end_date = Date.parse(event["end_date"])
  days_diff = (Date.today - event_end_date).to_i

  return days_diff > 2
end

def get_stats(event_key, stat, use_prev_event_data)
  if !use_prev_event_data
    return run_event(event_key, stat)
  end

  # get data from prev event instead
  team_last_events = get_teams_last_event(event_key)

  team_results = {}

  team_last_events.each do |team_key, event_key|
    team_number = team_key.sub('frc', '')
    event_results = run_event(event_key, stat)
    team_results[team_number] = event_results[team_number]
  end

  return team_results
end


def run_event(event_key, stat)
  if !event_key
      raise "No event key"
  end

  event = get_event(event_key)
  matches = get_event_matches(event_key)

  team_scores = {}

  cache_file_name = "cache/event_stat_cache_#{event_key}_#{stat}.json"
  if File.exists?(cache_file_name)
    return File.open(cache_file_name) { |f| JSON.load(f) }
  else
    print(".")
    if stat == "auto_leave"
      team_scores = run_auto_stats(matches)
    elsif stat == "deepcage"
      team_scores = run_endgame_stats(matches)
    else
      50.times do
        team_scores = run_iteration(stat, team_scores, matches)
        #pprint(team_scores)
      end

      if stat == "eps_v_comp"
        team_scores.each do |team_key, score_hash|
          score_hash["score"] -= get_avg_eps_for_week(event["week"])
        end
      end
    end

    if is_event_cacheable(event)
      File.open(cache_file_name, "w") do |file|
        JSON.dump(team_scores, file)
      end
    end
  end

  return team_scores
end

def run_endgame_stats(matches)
  team_info = {}

  matches.each do |match|
    next if !match['actual_time']

    team1, team2, team3 = match["alliances"]["blue"]["team_keys"].map { |key| key.sub('frc', '') }
    team4, team5, team6 = match["alliances"]["red"]["team_keys"].map { |key| key.sub('frc', '') }

    [team1, team2, team3, team4, team5, team6].each do |team|
      team_info[team] = {"match_count"=>0, "deepcage_count"=>0, "no_climbs"=>[]} if !team_info.key?(team)
    end

    bot_mappings = {
      ["blue", "1"] => team1,
      ["blue", "2"] => team2,
      ["blue", "3"] => team3,
      ["red", "1"] => team4,
      ["red", "2"] => team5,
      ["red", "3"] => team6,
    }

    mapping_str = "endGameRobot" 
    bot_mappings.each do |bot_mapping, team_id|
      team_info[team_id]["match_count"] += 1
      if match["score_breakdown"][bot_mapping[0]][mapping_str + bot_mapping[1]] == "DeepCage"
        team_info[team_id]["deepcage_count"] += 1
      else
        team_info[team_id]["no_climbs"].append(match["key"])
      end
    end
  end

  team_info.each do |team, data|
    team_info[team]["score"] = team_info[team]["deepcage_count"].to_f / team_info[team]["match_count"]
  end

  idx=0
  team_info.sort_by { |team, score| score["score"] }.reverse.each do |team, score|
    puts "#{idx+=1}. #{team} - #{score["score"].round(2)} bad:#{tids(team_info[team]['no_climbs'])}"
  end

  return team_info
end

def run_auto_stats(matches)
  team_info = {}

  matches.each do |match|
    next if !match['actual_time']

    team1, team2, team3 = match["alliances"]["blue"]["team_keys"].map { |key| key.sub('frc', '') }
    team4, team5, team6 = match["alliances"]["red"]["team_keys"].map { |key| key.sub('frc', '') }

    [team1, team2, team3, team4, team5, team6].each do |team|
      team_info[team] = {"match_count"=>0, "good_autos"=>[], "bad_autos"=>[], "leave_count"=>0} if !team_info.key?(team)
    end

    bot_mappings = {
      ["blue", "1"] => team1,
      ["blue", "2"] => team2,
      ["blue", "3"] => team3,
      ["red", "1"] => team4,
      ["red", "2"] => team5,
      ["red", "3"] => team6,
    }

    mapping_str = "autoLineRobot" 
    bot_mappings.each do |bot_mapping, team_id|
      team_info[team_id]["match_count"] += 1
      if match["score_breakdown"][bot_mapping[0]][mapping_str + bot_mapping[1]] == "Yes"
        team_info[team_id]["good_autos"].append(match["key"])
        team_info[team_id]["leave_count"] += 1
      else
        team_info[team_id]["bad_autos"].append(match["key"])
      end
    end
  end

  team_info.each do |team, data|
    team_info[team]["score"] = team_info[team]["leave_count"].to_f / team_info[team]["match_count"]
  end

  idx=0
  team_info.sort_by { |team, score| score["score"] }.reverse.each do |team, score|
    puts "#{idx+=1}. #{team} - #{score["score"].round(2)} bad:#{tids(team_info[team]['bad_autos'])}"
  end


  return team_info
end


def run_iteration(stat, team_scores, matches)
  iteration_team_scores = {}

  matches.each do |match|
    next if !match['actual_time']

    team1, team2, team3 = match["alliances"]["blue"]["team_keys"].map { |key| key.sub('frc', '') }
    team4, team5, team6 = match["alliances"]["red"]["team_keys"].map { |key| key.sub('frc', '') }

    blue_score = 0
    red_score = 0
      
    case stat
    when "eps", 'eps_v_comp'
      blue_score = match["score_breakdown"]["blue"]["totalPoints"] - match["score_breakdown"]["blue"]["foulPoints"]
      red_score = match["score_breakdown"]["red"]["totalPoints"] - match["score_breakdown"]["red"]["foulPoints"]
    when "wall_algae_count"
      blue_score = match["score_breakdown"]["blue"]["wallAlgaeCount"]
      red_score = match["score_breakdown"]["red"]["wallAlgaeCount"]
    when "net_algae_count"
      blue_score = match["score_breakdown"]["blue"]["netAlgaeCount"]
      red_score = match["score_breakdown"]["red"]["netAlgaeCount"]
    when "teleop_trough_count"
      blue_score = match["score_breakdown"]["blue"]["teleopReef"]["trough"]
      red_score = match["score_breakdown"]["red"]["teleopReef"]["trough"]
    when "foul_points_committed" 
      # look at opponent alliance foulPoints - TBA looks at own alliance which is meaningless
      blue_score = match["score_breakdown"]["red"]["foulPoints"]
      red_score = match["score_breakdown"]["blue"]["foulPoints"]
    end

    [team1, team2, team3, team4, team5, team6].each do |team|
      team_scores[team] ||= { "score" => 0 }
      iteration_team_scores[team] ||= { "score" => 0, "matches" => 0 }
    end

    alliance1_total = [team_scores[team1]["score"], team_scores[team2]["score"], team_scores[team3]["score"]].sum
    if alliance1_total == 0
      alliance1_percentages = [1.0/3, 1.0/3, 1.0/3]
    else
      alliance1_percentages = [team_scores[team1]["score"], team_scores[team2]["score"], team_scores[team3]["score"]].map { |score| score.to_f / alliance1_total }
    end

    alliance2_total = [team_scores[team4]["score"], team_scores[team5]["score"], team_scores[team6]["score"]].sum
    if alliance2_total == 0
      alliance2_percentages = [1.0/3, 1.0/3, 1.0/3]
    else
      alliance2_percentages = [team_scores[team4]["score"], team_scores[team5]["score"], team_scores[team6]["score"]].map { |score| score.to_f / alliance2_total }
    end

    iteration_team_scores[team1]["score"] += alliance1_percentages[0] * blue_score.to_i
    iteration_team_scores[team2]["score"] += alliance1_percentages[1] * blue_score.to_i
    iteration_team_scores[team3]["score"] += alliance1_percentages[2] * blue_score.to_i

    iteration_team_scores[team4]["score"] += alliance2_percentages[0] * red_score.to_i
    iteration_team_scores[team5]["score"] += alliance2_percentages[1] * red_score.to_i
    iteration_team_scores[team6]["score"] += alliance2_percentages[2] * red_score.to_i

    [team1, team2, team3, team4, team5, team6].each do |team|
      iteration_team_scores[team]["matches"] += 1
    end

  end

  iteration_team_scores.map do |team, score|
    team_scores[team]["score"] = score["score"] / score["matches"]
  end

  team_scores
end

def get_teams_last_event(event_key)
  # ignore championship events with very few matches
  unusable_events = ["2025txcmp", "2025micmp", "2025necmp", "2025oncmp"]

  cache_file_name = "cache/last_event_cache_#{event_key}.json"
  if File.exists?(cache_file_name)
    return File.open(cache_file_name) { |f| JSON.load(f) }
  end

  team_keys = get_team_keys(event_key)

  team_last_event_map = {}
  team_keys.each do |team_key|
    matches = query("team/#{team_key}/matches/2025")
    filtered_matches = matches.select { |match| match["actual_time"] }
    filtered_matches = filtered_matches.reject { |match| unusable_events.include?(match["event_key"]) }
    most_recent_match = filtered_matches.max_by { |match| match["actual_time"] }
    if most_recent_match
      team_last_event_map[team_key] = most_recent_match["event_key"]
    end
    print('.')
  end

  File.open(cache_file_name, "w") do |file|
    JSON.dump(team_last_event_map, file)
  end

  return team_last_event_map
end

def get_team_keys(event_key)
  teams = query("event/#{event_key}/teams")
  return teams.map{ |team| team["key"] }
end

# repopulate this cache each run
WEEKLY_AVG_EPS_CACHE = {}
def get_avg_eps_for_week(week_num)
  if WEEKLY_AVG_EPS_CACHE[week_num]
    return WEEKLY_AVG_EPS_CACHE[week_num]
  end

  event_averages = []
  events = query("events/2025")
  events.each do |event|
    next if event["week"].nil?
    next if event["week"].to_i != week_num.to_i

    event_results = run_event(event["key"], "eps")
    scores = event_results.values.map { |team| team["score"] }
    total_score = scores.sum
    average_score = total_score / scores.size
    event_averages.append(average_score)
  end

  average_eps = event_averages.sum / event_averages.count
  WEEKLY_AVG_EPS_CACHE[week_num] = average_eps
  return average_eps
end

def pprint(team_scores)
  idx = 0

  puts "\n==================="
  if team_scores.length == 0
    puts "No data yet"
  else
    team_scores.sort_by { |team, score| score["score"] }.reverse.each do |team, score|
      puts "#{idx+=1}. #{team}: #{score["score"].round(2)}"
    end
  end
end

def display_menu()
  puts "\n\n"
  puts "###################################################################\n#"
  if ARGV[1].nil?
    puts "#     Stats for #{ARGV[0]} teams using #{ARGV[0]} matches"
  else
    puts "#     Stats for #{ARGV[0]} teams using teams' latest event matches"
  end
  puts "#\n###################################################################"
  puts "\n"
  puts "1)  Estimated Points Share (sans fouls)"
  puts "2)  EPS vs Week Comp"
  puts "3)  Teleop Trough Count"
  puts "4)  Foul Points Committed"
  puts "5)  Auto Leave %"
  puts "6)  Deep Cage %"
  puts "7)  Wall Algae Count"
  puts "8)  Net Algae Count"
  puts ""
  puts "[w]eekly average scores"
  puts "[c]lear cache"
  puts "[q]uit"
  puts ""
  print "Enter choice: "
end

def run_match_forecast(event_key, team_scores)
  matches = get_event_matches(event_key)
  matches.each do |match|
    #next if !match['actual_time']

    team1, team2, team3 = match["alliances"]["blue"]["team_keys"].map { |key| key.sub('frc', '') }
    team4, team5, team6 = match["alliances"]["red"]["team_keys"].map { |key| key.sub('frc', '') }

    blue_total = (team_scores[team1]["score"] + team_scores[team2]["score"] + team_scores[team3]["score"]).round()
    red_total = (team_scores[team4]["score"] + team_scores[team5]["score"] + team_scores[team6]["score"]).round()

    puts "#{match["key"]}:   \t #{red_total} \t- #{blue_total}     \t(#{team4} #{team5} #{team6}) - (#{team1} #{team2} #{team3})"
  end
end

def handle_choice(choice)
  # if there is a second command line arg of any kind.. we use prev event
  use_prev_event_data = !ARGV[1].nil?

  choice_map = {
    "1" => "eps",
    "2" => "eps_v_comp",
    "3" => "teleop_trough_count",
    "4" => "foul_points_committed",
    "5" => "auto_leave",
    "6" => "deepcage",
    "7" => "wall_algae_count",
    "8" => "net_algae_count",
  }

  event_key = ARGV[0]

  case choice
  when *choice_map.keys
    pprint(get_stats(event_key, choice_map[choice], use_prev_event_data))
  when "c"
    FileUtils.rm_rf("cache")
    FileUtils.mkdir_p("cache")
  when "w"
    puts("Week 1: #{get_avg_eps_for_week(0)}")
    puts("Week 2: #{get_avg_eps_for_week(1)}")
    puts("Week 3: #{get_avg_eps_for_week(2)}")
  end
end

def run_menu()
  FileUtils.mkdir_p("cache")
  choice = ''
  until choice == 'q'
    display_menu()
    choice = STDIN.gets.chomp
    handle_choice(choice)
  end
end

def tids(input)
  if input.is_a?(Array)
    res = input.map { |str| str.split('_', 2)[1] }
    res.sort_by { |res| res[/\d+/].to_i }
  elsif input.is_a?(String)
    input.split('_', 2)[1]
  end
end

run_menu()

