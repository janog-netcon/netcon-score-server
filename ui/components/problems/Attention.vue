<template>
  <v-sheet class="warning lighten-2 pa-2">
    <span class="subtitle-1"> 解答時の注意点 </span>
    <ul>
      <template v-if="!realtimeGrading">
        <li>採点は競技終了後に行われます。</li>
        <li>採点されるのは最後に提出した解答のみです。</li>
        <li>競技中は何度でも再解答可能です。</li>
      </template>
      <template v-else-if="gradingDelaySec !== 0">
        <li>
          自動採点が対応している問題の場合、採点結果は解答を提出してから3分以内には返ってきます。
        </li>
        <li>手動採点の場合はベストエフォートで採点をしています。夜間は手動採点をしていません。</li>
        <li>採点中はその問題へ再解答できません。</li>
      </template>

      <li>
        採点はその解答の内容のみを見て行います。複数の解答をまたがず1つの解答内に全ての内容を収めてください。
      </li>
    </ul>
  </v-sheet>
</template>

<script>
import { mapGetters } from 'vuex'

export default {
  name: 'Attention',
  computed: {
    ...mapGetters('contestInfo', [
      'gradingDelaySec',
      'gradingDelayString',
      'realtimeGrading',
    ]),

    aboutGradingDelayTitle() {
      return `運営が採点 (最速${this.gradingDelayString})`
    },
  },
}
</script>
