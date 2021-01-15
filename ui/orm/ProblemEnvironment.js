import orm from '~/orm'
import BaseModel from '~/orm/BaseModel'

export default class ProblemEnvironment extends BaseModel {
  static entity = 'problemEnvironments'

  static fields() {
    return {
      id: this.string(),
      teamId: this.string().nullable(),
      team: this.belongsTo(orm.Team, 'teamId'),
      problemId: this.string(),
      problem: this.belongsTo(orm.Problem, 'problemId'),
      name: this.string(),
      service: this.string(),
      status: this.string().nullable(),
      externalStatus: this.string().nullable(),
      host: this.string(),
      port: this.number(),
      user: this.string(),
      password: this.string(),
      secretText: this.string().nullable(),
      project: this.string().nullable(),
      zone: this.string().nullable(),
      createdAt: this.string(),
      updatedAt: this.string(),
    }
  }

  static mutationFields() {
    return {
      problemCode: undefined,
      teamNumber: undefined,
      name: '',
      service: 'SSH',
      status: 'APPLIED',
      externalStatus: 'APPLIED',
      host: '',
      port: 22,
      user: '',
      password: '',
      secretText: '',
      project: '',
      zone: '',
    }
  }

  get teamNumber() {
    return this.team && this.team.number
  }

  get problemCode() {
    return this.problem && this.problem.code
  }

  get sshCommand() {
    return `ssh ${this.user}@${this.host} -p ${this.port}`
  }

  get copyText() {
    if (/^SSH$/i.test(this.service)) {
      return { text: this.sshCommand }
      // return {
      //   text: `sshpass -p "${this.password}" ${this.sshCommand}`,
      //   display: 'sshpassコマンド',
      //   tooltip: 'sshpassコマンドを使うとpassword入力の手間が省けます',
      // }
    } else if (/^SSH\(公開鍵\)$/i.test(this.service)) {
      return {
        text: this.sshCommand,
        display: 'sshコマンド',
      }
    } else if (/^HTTP$/i.test(this.service)) {
      if (this.port === 80) {
        return { text: `http://${this.host}/` }
      } else {
        return { text: `http://${this.host}:${this.port}/` }
      }
    } else if (/^HTTPS$/i.test(this.service)) {
      if (this.port === 443) {
        return { text: `https://${this.host}/` }
      } else {
        return { text: `https://${this.host}:${this.port}/` }
      }
    } else if (/^Telnet$/i.test(this.service)) {
      return { text: `telnet ${this.host} ${this.port}` }
    } else if (/^VNC$/i.test(this.service)) {
      return { text: `${this.host}:${this.port}` }
    } else {
      // コピー対象無し
      return { text: '' }
    }
  }

  static get supportedServices() {
    return ['SSH', 'SSH(公開鍵)', 'HTTP', 'HTTPS', 'Telnet', 'VNC']
  }
}
