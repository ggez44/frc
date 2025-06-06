require 'date'
require 'fileutils'
require 'uri'
require 'net/http'
require 'json'

require 'byebug'

API_KEY = "bUdXNYQIL7C5HYLSX966jAqfpmjbzocnaCoTdABBsOaHFAuyyid781XDRxwOrZD4"
GLOBAL_GOOD_TRAPS = {}

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
    if stat == "amplified_note_ratio"
      team_scores = run_amplified_note_ratio(event_key)
    elsif stat == "endgame_stats"
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
      team_info[team] = {"match_count"=>0, "none_count"=>0, "parked_count"=>0, "climbed_count"=>0, "trapped_count"=>0} if !team_info.key?(team)
    end

    bot_mappings = {
      ["blue", "endGameRobot1"] => team1,
      ["blue", "endGameRobot2"] => team2,
      ["blue", "endGameRobot3"] => team3,
      ["red", "endGameRobot1"] => team4,
      ["red", "endGameRobot2"] => team5,
      ["red", "endGameRobot3"] => team6,
    }

    bot_mappings.each do |bot_mapping, team_id|
      endgame_status = match["score_breakdown"][bot_mapping[0]][bot_mapping[1]]
      
      team_info[team_id]["match_count"] += 1

      if endgame_status == "None"
        team_info[team_id]["none_count"] += 1
      elsif endgame_status == "Parked"
        team_info[team_id]["parked_count"] += 1
      else
        team_info[team_id]["climbed_count"] += 1
        if match["score_breakdown"][bot_mapping[0]]["trap#{endgame_status}"]
          team_info[team_id]["trapped_count"] += 1

          if !GLOBAL_GOOD_TRAPS.keys.include?(team_id)
            GLOBAL_GOOD_TRAPS[team_id] = []
          end
          GLOBAL_GOOD_TRAPS[team_id] << "https://www.thebluealliance.com/match/#{match["key"]}"
        end
      end
    end
  end

  return team_info
end

def run_amplified_note_ratio(event_key)
  amplified_note_scores = run_event(event_key, "amplified_notes")
  unamplified_note_scores = run_event(event_key, "unamplified_notes")

  result_scores = {}
  amplified_note_scores.each do |team, score_hash|
    result_scores[team] = {"score" => amplified_note_scores[team]["score"] / unamplified_note_scores[team]["score"]}
  end

  return result_scores
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
      blue_score = match["score_breakdown"]["blue"]["totalPoints"]
      red_score = match["score_breakdown"]["red"]["totalPoints"]
    when "total_notes"
      keys_to_sum = ["autoAmpNoteCount", "autoSpeakerNoteCount", "teleopAmpNoteCount", "teleopSpeakerNoteAmplifiedCount", "teleopSpeakerNoteCount"]
      blue_score = keys_to_sum.sum { |key| match["score_breakdown"]["blue"][key] || 0 }
      red_score = keys_to_sum.sum { |key| match["score_breakdown"]["red"][key] || 0 }
    when "auto_notes"
      keys_to_sum = ["autoAmpNoteCount", "autoSpeakerNoteCount"]
      blue_score = keys_to_sum.sum { |key| match["score_breakdown"]["blue"][key] || 0 }
      red_score = keys_to_sum.sum { |key| match["score_breakdown"]["red"][key] || 0 }
    when "teleop_notes"
      keys_to_sum = ["teleopAmpNoteCount", "teleopSpeakerNoteAmplifiedCount", "teleopSpeakerNoteCount"]
      blue_score = keys_to_sum.sum { |key| match["score_breakdown"]["blue"][key] || 0 }
      red_score = keys_to_sum.sum { |key| match["score_breakdown"]["red"][key] || 0 }
    when "amplified_notes"
      blue_score = match["score_breakdown"]["blue"]["teleopSpeakerNoteAmplifiedCount"]
      red_score = match["score_breakdown"]["red"]["teleopSpeakerNoteAmplifiedCount"]
    when "unamplified_notes"
      keys_to_sum = ["teleopAmpNoteCount", "teleopSpeakerNoteCount"]
      blue_score = keys_to_sum.sum { |key| match["score_breakdown"]["blue"][key] || 0 }
      red_score = keys_to_sum.sum { |key| match["score_breakdown"]["red"][key] || 0 }
    when "epps" 
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
  unusable_events = ["2024txcmp", "2024micmp", "2024necmp", "2024oncmp"]

  cache_file_name = "cache/last_event_cache_#{event_key}.json"
  if File.exists?(cache_file_name)
    return File.open(cache_file_name) { |f| JSON.load(f) }
  end

  team_keys = get_team_keys(event_key)

  team_last_event_map = {}
  team_keys.each do |team_key|
    matches = query("team/#{team_key}/matches/2024")
    filtered_matches = matches.select { |match| match["actual_time"] }
    filtered_matches = filtered_matches.reject { |match| unusable_events.include?(match["event_key"]) }
    most_recent_match = filtered_matches.max_by { |match| match["actual_time"] }
    team_last_event_map[team_key] = most_recent_match["event_key"]
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
  events = query("events/2024")
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
      puts "#{idx+=1}. #{team} - #{score["score"].round(2)}"
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
  puts "3)  Total Notes"
  puts "4)  Auto Notes"
  puts "5)  Teleop Notes"
  puts "6)  Amplified Note Ratio (amped speaker:unamped+amp)"
  puts "7)  Estimated Penalty Points Share (more is bad)"
  puts "8)  Endgame Stats (sorted by climbed/match)"
  puts "9)  Endgame Stats (sorted by trapped/climb)"
  puts "10) Match Num Pieces Forecast"
  puts "11) Match Score Forecast"
  puts ""
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

def print_endgame_stats(sorted_endgame_stats)
  puts "team \t matches \t nothing \t parked \t climbed/match \t\t trapped/climb"
  sorted_endgame_stats.each do |team_id, stat|
    climbed_perc = (stat["climbed_count"].to_f / stat["match_count"]).round(2)
    trapped_perc = (stat["trapped_count"].to_f / stat["climbed_count"]).round(2)
    puts "#{team_id} \t #{stat['match_count']} \t\t #{stat['none_count']} \t\t #{stat['parked_count']} \t\t #{stat['climbed_count']}\t(#{climbed_perc}) \t\t #{stat['trapped_count']}\t(#{trapped_perc})"
  end

  sorted_endgame_stats.each do |team_id, stat|
    team_good_traps = GLOBAL_GOOD_TRAPS[team_id]
    next if !team_good_traps
    puts team_id
    team_good_traps.each do |team_good_trap|
      puts team_good_trap
    end
  end
end

def handle_choice(choice)
  # if there is a second command line arg of any kind.. we use prev event
  use_prev_event_data = !ARGV[1].nil?

  choice_map = {
    "1" => "eps",
    "2" => "eps_v_comp",
    "3" => "total_notes",
    "4" => "auto_notes",
    "5" => "teleop_notes",
    "6" => "amplified_note_ratio",
    "7" => "epps",
  }

  event_key = ARGV[0]

  case choice
  when *choice_map.keys
    pprint(get_stats(event_key, choice_map[choice], use_prev_event_data))
  when "8"
    endgame_stats = get_stats(event_key, "endgame_stats", use_prev_event_data)

    sorted_endgame_stats = endgame_stats.sort_by do |team_id, hash|
        -(hash["climbed_count"].to_f / hash["match_count"].to_f)
    end

    print_endgame_stats(sorted_endgame_stats)
  when "9"
    endgame_stats = get_stats(event_key, "endgame_stats", use_prev_event_data)

    sorted_endgame_stats = endgame_stats.sort_by do |team_id, hash|
      if hash["climbed_count"].to_f == 0
        0
      else
        -(hash["trapped_count"].to_f / hash["climbed_count"].to_f)
      end
    end

    print_endgame_stats(sorted_endgame_stats)
  when "10"
    total_note_scores = get_stats(event_key, "total_notes", use_prev_event_data)

    run_match_forecast(event_key, total_note_scores)
  when "11"
    eps_scores = get_stats(event_key, "eps", use_prev_event_data)

    run_match_forecast(event_key, eps_scores)
  when "c"
    FileUtils.rm_rf("cache")
    FileUtils.mkdir_p("cache")
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

run_menu()

