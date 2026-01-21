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

    <v-row justify="center" align="center">
      <span class="headline mt-12">
        Supported By:
      </span>
    </v-row>

    <v-row justify="center" align="center" class="mb-12">
      <v-col
        v-for="(logo, i) in logos"
        :key="i"
        cols="3"
        class="text-center pa-4"
      >
        <a
          :href="logo.href"
          target="_blank"
          rel="noopener noreferrer"
          class="d-inline-block"
        >
          <img
            :src="logo.src"
            :style="logo.style"
            style="height: 80px; max-width: min(90%, 240px); object-fit: contain; mix-blend-mode: multiply;"
          />
        </a>
      </v-col>
    </v-row>
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
    logos() {
      return [
        {
          src: require('~/assets/img/JANOG57_sakura.svg'),
          href: 'https://www.sakura.ad.jp/',
        },
        {
          src: require('~/assets/img/JANOG57_keysight.png'),
          href: 'https://www.keysight.co.jp'
        },
        {
          src: require('~/assets/img/JANOG57_ASE-Net.png'),
          href: 'https://www.asenet.co.jp/',
          style: "height: 100px;"
        },
        {
          src: require('~/assets/img/JANOG57_Sticklers.jpg'),
          href: 'https://www.asenet.co.jp/sticklers/',
        },
        {
          src: require('~/assets/img/JANOG57_HARADA.jpg'),
          href: 'https://infocom.haradacorp.co.jp/',
        },
        {
          src: require('~/assets/img/JANOG57_EXFO.png'),
          href: 'https://www.exfo.com/en/',
        },
        {
          src: require('~/assets/img/JANOG57_furukawa.png'),
          href: 'https://www.furukawa.co.jp/',
        },
        {
          src: require('~/assets/img/JANOG57_76.png'),
        },
        {
          src: require('~/assets/img/JANOG57_NIPPON_SEISEN.png'),
          style: "max-width: min(100%, 300px);"
        },
        {
          src: require('~/assets/img/JANOG57_SEICOH_GIKEN.png'),
          style: "height: 70px;"
        },
        {
          src: require('~/assets/img/JANOG57_fortinet.png'),
          style: "max-width: min(100%, 300px);"
        },
      ]
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
