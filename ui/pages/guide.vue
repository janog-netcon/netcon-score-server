<template>
  <v-container>
    <v-row justify="center" align="center">
      <page-title :title="title">
        <pen-button
          v-if="isStaff"
          :loading="!configGuidePageJa || !configGuidePageEn"
          elevation="2"
          x-small
          absolute
          class="ml-2 mb-4"
          @click="enableModal"
        />
      </page-title>
    </v-row>

    <v-row justify="center" align="center">
      <switch-language-buttons v-model="language" />
    </v-row>

    <v-row>
      <markdown v-if="language === 'ja'" :content="guidePage" />
      <markdown v-if="language === 'en'" :content="guidePageEn" />
    </v-row>

    <config-modal
      v-if="isStaff && !!configGuidePageJa"
      v-model="showModalJa"
      :config="configGuidePageJa"
    />

    <config-modal
      v-if="isStaff && !!configGuidePageEn"
      v-model="showModalEn"
      :config="configGuidePageEn"
    />
  </v-container>
</template>
<script>
import { mapGetters } from 'vuex'
import orm from '~/orm'
import ConfigModal from '~/components/misc/ConfigModal'
import Markdown from '~/components/commons/Markdown'
import PageTitle from '~/components/commons/PageTitle'
import PenButton from '~/components/commons/PenButton'
import SwitchLanguageButtons from '~/components/guide/SwitchLanguageButtons'

export default {
  name: 'Guide',
  components: {
    ConfigModal,
    Markdown,
    PageTitle,
    PenButton,
    SwitchLanguageButtons,
  },
  data() {
    return {
      language: 'ja',
      showModalJa: false,
      showModalEn: false,
    }
  },
  computed: {
    ...mapGetters('contestInfo', ['guidePage']),
    ...mapGetters('contestInfo', ['guidePageEn']),
    title() {
      if (this.language === 'ja') {
        return 'ガイド'
      } else {
        return 'Guide'
      }
    },
    configGuidePageJa() {
      return orm.Config.find('guide_page')
    },
    configGuidePageEn() {
      return orm.Config.find('guide_page_en')
    },
  },
  watch: {
    isStaff: {
      immediate: true,
      handler(value) {
        if (value) {
          orm.Queries.configs()
        }
      },
    },
  },
  methods: {
    enableModal() {
      if (this.language === 'ja') {
        this.showModalJa = true
      } else {
        this.showModalEn = true
      }
    },
  }
}
</script>
