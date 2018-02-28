require 'rest-client'
require 'json'
require 'yaml'

host = ARGV[0] || 'localhost'
$base_url = "http://#{host}:3000/api"
$responses = []

def build_url(path)
  File.join($base_url, path)
end

def request(method, path, payload_hash = {}, headers = { content_type: :json })
  headers[:cookies] ||= $responses.last&.cookies
  payload = headers[:content_type] == :json ? payload_hash.to_json : payload_hash

  $responses << RestClient::Request.execute(method: method.to_sym, url: build_url(path), payload: payload, headers: headers)
  $responses.last
end

def login_as(login:, password:)
  JSON.parse(request(:post, 'session', { login: login, password: password }))
end

def logout
  JSON.parse(request(:delete, 'session'))
end

def add_problem_group(name:, description:, visible: true, completing_bonus_point: 0, flag_icon_url: '')
  data = {
    name: name,
    description: description,
    visible: visible,
    completing_bonus_point: completing_bonus_point,
    flag_icon_url: flag_icon_url,
  }

  request(:post, 'problem_groups', data)
end

def add_problem(title:, text:, reference_point:, perfect_point:, creator_id:, problem_group_ids:, problem_must_solve_before_id:)
  data = {
    title: title,
    text: text,
    reference_point: reference_point,
    perfect_point: perfect_point,
    creator_id: creator_id,
    problem_must_solve_before_id: problem_must_solve_before_id,
    problem_group_ids: problem_group_ids,
  }

  JSON.parse(request(:post, 'problems', data))
end

# def update_problem(id:, title:, text:, reference_point:, perfect_point:, creator_id:, problem_group_ids:, problem_must_solve_before_id:)
def update_problem(problem_hash)
  JSON.parse(request(:put, "problems/#{problem_hash['id']}", problem_hash))
end

def add_team(name:, organization:, registration_code:)
  data = {
    name: name,
    organization: organization,
    registration_code: registration_code,
  }
  JSON.parse(request(:post, 'teams', data))
end

def add_teams_from_hash(teams)
  teams.each do |t|
    puts add_team(
      name: t['name'],
      organization: t['organization'],
      registration_code: t['registration_code'],
    )
  end
end

def list_members()
  JSON.parse(request(:get, 'members'))
end

def list_problems(with: [])
  with_params = with.empty? ? '' : "?with=#{with.join(',')}"
  JSON.parse(request(:get, 'problems' + with_params))
end

def list_problem_groups()
  JSON.parse(request(:get, 'problem_groups'))
end

def add_attachments(filepath)
  full_filepath = File.expand_path(filepath)
  JSON.parse(request(:post, 'attachments', { file: File.open(full_filepath, 'rb'),  multipart: true }, {}))
end

def list_attachments
  JSON.parse(request(:get, 'attachments'))
end

def download_attachments(id:, file_hash:, file_name:)
  # これだけ /api がいらないから
  path = "../attachments/#{id}/#{file_hash}/#{file_name}"
  JSON.parse(request(:get, path))
end


# role_id: 2=admin, 3=writer 4=participant 5=viewer
# writer,admin,viewerは team_idとregistration_codeをnullにしてrole_idを指定する
# participantはrole_idを指定しないでもいい
def add_member(name:, login:, password:, team_id:, registration_code:, role_id:)
  data = {
    name: name,
    login: login,
    password: password,
    team_id: team_id,
    registration_code: registration_code,
    role_id: role_id,
  }
  JSON.parse(request(:post, 'members', data))
end

def add_members_from_hash(members)
  members.each do |m|
    puts add_member(
      name: m['name'],
      login: m['login'],
      password: m['password'],
      team_id: m['team_id'],
      registration_code: m['registration_code'],
      role_id: m['role_id'],
    )
  end
end

# まとめて流し込み系
# YAML,JSONを読み込む
def parse_file(filepath)
  filepath = File.expand_path(filepath)
  case File.extname(filepath)
  when '.yml', '.yaml'
    YAML.load(File.read(filepath))
  when '.json'
    JSON.parse(File.read(filepath))
  end
end

def add_problems_from_hash(problems)
  problems.each do |p|
    puts add_problem(
      title: p['title'],
      text: p['text'],
      reference_point: p['reference_point'],
      perfect_point: p['perfect_point'],
      creator_id: p['creator_id'],
      problem_must_solve_before_id: p['problem_must_solve_before_id'],
      problem_group_ids: p['problem_group_ids'],
    )
  end
end

def add_problem_groups_from_hash(problem_groups)
  problem_groups.each do |g|
    puts add_problem_group(
      name: g['name'],
      description: g['description'],
      visible: g['visible'],
      completing_bonus_point: g['completing_bonus_point'],
      flag_icon_url: g['flag_icon_url'],
    )
  end
end

# TODO: valid_probleとか作るproblemからproblem_groupを読み取って自動で作る


#### 操作サンプル(雑) ####

puts r_login = login_as(login: 'admin', password: 'admin')
# puts r_login = login_as(login: 'f_1', password: 'f_1')

# puts add_attachments('./pry_r.rb')

# puts add_problem(title: '10時間寝たい', text: 'マジ?', reference_point: 80, perfect_point: 0x80, creator_id: 3, problem_group_ids: [1], problem_must_solve_before_id: 12)


# puts new_groups = parse_file('./sample-problem-groups.yml')
# puts add_problems_from_hash(new_groups)

# problem = list_problems
# problem['title'] = 'this is a title'
# puts update_problem(problem)

def update_only_problem_group(problem_id:, group_id:)
  problem = list_problems.find{|e| e['id'] == problem_id }
  problem['problem_group_ids'] = [group_id]
  update_problem(problem)
end

# afterはbeforeに依存する
def change_depends_problem(before_id:, after_id:)
  after_problem = list_problems.find {|e| e['id'] == after_id }
  after_problem['problem_must_solve_before_id'] = before_id
  update_problem(after_problem)
end

def register_problems_to_group(group_id:, problem_ids: [])
  problem_ids.each do |id|
    update_only_problem_group(problem_id: id, group_id: group_id)
  end
end

require 'pry'
binding.pry
puts '[*] end binding'

__END__
