export default {
  state() {
    return {
      competitionTime: [],
      gradingDelaySec: 0,
      guidePage: '',
      guidePageEn: '',
      localProblemCodes: '',
      hideAllScore: false,
      realtimeGrading: false,
      resetDelaySec: 0,
    }
  },
  mutations: {
    setContestInfo(state, contestInfo) {
      state.competitionTime = contestInfo.competitionTime.map((daterange) =>
        daterange.map((date) => new Date(date))
      )

      state.gradingDelaySec = contestInfo.gradingDelaySec
      state.guidePage = contestInfo.guidePage
      state.guidePageEn = contestInfo.guidePageEn
      state.localProblemCodes = contestInfo.localProblemCodes
      state.hideAllScore = contestInfo.hideAllScore
      state.realtimeGrading = contestInfo.realtimeGrading
      state.resetDelaySec = contestInfo.resetDelaySec
    },
  },
  actions: {
    async fetchContestInfo({ state, commit, dispatch }) {
      const keys = Object.keys(state)
      const query = `query ContestInfo { contestInfo { ${keys} } }`

      try {
        const res = await dispatch(
          'entities/simpleQuery',
          { query, bypassCache: true },
          { root: true }
        )

        commit('setContestInfo', res.contestInfo)
      } catch (error) {
        // セッションが無い、ネットワーク疎通がないなど
        console.info(error)
      }
    },
  },
  getters: {
    competitionTime: (state) => state.competitionTime,
    gradingDelaySec: (state) => state.gradingDelaySec,
    guidePage: (state) => state.guidePage,
    guidePageEn: (state) => state.guidePageEn,
    localProblemCodes: (state) => state.localProblemCodes,
    hideAllScore: (state) => state.hideAllScore,
    realtimeGrading: (state) => state.realtimeGrading,
    resetDelaySec: (state) => state.resetDelaySec,

    gradingDelayString: (state, getters) =>
      $nuxt.timeSimpleStringJp(getters.gradingDelaySec),
    resetDelayString: (state, getters) =>
      $nuxt.timeSimpleStringJp(getters.resetDelaySec),
  },
}
