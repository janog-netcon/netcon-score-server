<template>
  <div>
    <div v-if="!isLocalProblem">
      <!-- VM作成・削除ボタン -->
      <v-btn
        contained
        color="success"
        @click="acquireProblemEnvironmentVM(problem.id)"
        v-if="isSolve"
        width="100%"
      >
        この問題にチャレンジする (接続情報を取得します)
      </v-btn>
      <v-btn
        contained
        color="error"
        @click="abandonProblemEnvironmentVM(problem.id)"
        v-if="isRetire"
        width="100%"
      >
        この問題を諦める (ペナルティはありません / 再チャレンジもできます)
      </v-btn>
      <v-btn
        contained
        disabled
        v-if="isLock"
        width="100%"
      >
        ロック中 (採点待ち、もしくは他の問題にチャレンジ中です)
      </v-btn>
    </div>
    <div v-else>
      <v-btn
        contained
        disabled
        width="100%"
      >
        この問題は現地問題です。現地にてチャレンジしてください。
      </v-btn>
    </div>
  </div>
</template>
<script>
import { mapGetters } from 'vuex'
import EnvironmentModal from '~/components/misc/EnvironmentModal'
import ExpandableButton from '~/components/commons/ExpandableButton'
import PlusButton from '~/components/commons/PlusButton'
import orm from '~/orm'

export default {
  name: 'EnvironmentArea',
  components: {
    EnvironmentModal,
    ExpandableButton,
    PlusButton,
  },
  props: {
    problem: {
      type: Object,
      required: true,
    },
    environments: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      search: '',
      show: true,
      showModal: false,
    }
  },
  computed: {
    ...mapGetters('contestInfo', ['localProblemCodes']),
    isLocalProblem() {
      for (const code of this.localProblemCodes.split(",")) {
        if (this.problem.code === code) {
          return true
        }
      }
      return false
    },
    //「棄権ボタン」を表示するかどうか
    isRetire() {
      //採点中・削除中は表示しない
      if(this.isUnderScoringAbandoned) {
        return false
      }
      return this.isUnderChallenge
    },
    //「この問題は現在解けません」ボタンを表示するかどうか
    isLock() {
      //この問題を解いてる時は表示しない
      if(this.isUnderChallenge) {
        return false
      }
      //全問題の中に解答中がある場合は表示する
      if (this.isUnderChallenges) {
        return true
      }
      //採点中・削除中はロックする
      if (this.isUnderScoringAbandoned) {
        return true
      }
      //完答してる場合はロックする
      if (this.isPerfect) {
        return true
      }
      return false
    },
    //「問題を解く」ボタンを表示するかどうか
    isSolve() {
      if( this.isRetire === true || this.isLock === true ) {
        return false
      } else {
        return true
      }
    },
    //解答中かどうか
    isUnderChallenge() {
      if (this.environments.length < 1) {
        return false
      }
      const status = this.environments[0].status
      if (status === "UNDER_CHALLENGE") {
        return true
      } else {
        return false
      }
    },
    //ユーザが解いている全問題の中にUNDER_CHALLENGEがある場合
    isUnderChallenges() {
      if (orm.ProblemEnvironment.all().filter((pe) => pe.status === "UNDER_CHALLENGE").length > 0) {
        return true
      } else {
        return false
      }
    },
    //採点中or削除中かどうか
    isUnderScoringAbandoned() {
      if (this.environments.length < 1) {
        return false
      }
      const status = this.environments[0].status
      // if (status === "UNDER_SCORING" || status === "ABANDONED") {
      if (status === "UNDER_SCORING") {
        return true
      } else {
        return false
      }
    },
    //問題が満点かどうか
    isPerfect() {
      // 採点済みの解答が無いなら '---'
      if (this.scoredAnswers.length === 0) {
        return false
      }
      if (this.maxScoreAnswer.point === this.problem.perfectPoint) {
        return true
      } else {
        return false
      }
    },
    scoredAnswers() {
      return this.problem.answers.filter((answer) => answer.hasPoint)
    },
    maxScoreAnswer() {
      const answer = this.$_.max(this.scoredAnswers, (answer) => answer.percent)
      return answer === -Infinity ? null : answer
    },
  },
  methods: {
    async acquireProblemEnvironmentVM(problemId) {
      await orm.Mutations.acquireProblemEnvironment({
        action: '問題VM確保',
        params: { problemId: problemId },
      })
    },
    async abandonProblemEnvironmentVM(problemId) {
      await orm.Mutations.abandonProblemEnvironment({
        action: '問題VM削除',
        params: { problemId: problemId },
      })
    },
  },
  watch: {
    isPlayer: {
      immediate: true,
      handler(value) {
        this.show = value
      },
    },
  },
}
</script>
