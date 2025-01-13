<template>
  <v-app-bar app dense color="secondary" elevation="1">
    <navigation-link to="/" active-class="" class="mr-2 ml-2">
      <v-img
        :src="require('~/assets/img/JANOG55_logo.png')"
        max-height="40px"
        max-width="160px"
        class="m-2"
        alt="JANOG55"
      />
      <div
        style="color: #1a1a1a; font-weight: 700; font-size: 22px; line-height: 1; letter-spacing: -1px; margin: auto 10px auto 5px;"
      >NETCON</div>
    </navigation-link>

    <v-spacer />

    <div
      style="font-weight: bold; margin: auto 8px 8px 0px"
    >Supported by:</div>
    <v-btn href="https://www.exfo.com/en/" class="mr-1 px-0" tile text height="48px">
      <img
        :src="require('~/assets/img/JANOG55_exfo.png')"
        style="margin: auto 2px; max-height: 36px"
        alt="EXFO JAPAN株式会社"
      />
    </v-btn>
    <v-btn href="https://infocom.haradacorp.co.jp/" class="mr-1 px-0" tile text height="48px">
      <img
        :src="require('~/assets/img/JANOG55_harada.jpg')"
        style="margin: auto 2px; max-height: 32px"
        alt="原田産業株式会社"
      />
    </v-btn>
    <v-btn href="https://www.asenet.co.jp/" class="mr-1 px-0" tile text height="48px">
      <img
        :src="require('~/assets/img/JANOG55_ase_net.png')"
        style="margin: auto 2px; max-height: 42px"
        alt="ASE-NET"
      />
    </v-btn>
    <!-- TODO: Fix link pages -->
    <v-btn href="https://www.asenet.co.jp/sticklers/" class="mr-1 px-0" tile text height="48px">
      <img
        :src="require('~/assets/img/JANOG55_sticklers.jpg')"
        style="margin: auto 2px; max-height: 32px"
        alt="ASE-NET"
      />
    </v-btn>
    <v-btn href="https://www.keysight.co.jp" class="mr-1 px-0" tile text height="48px">
      <img
        :src="require('~/assets/img/JANOG55_keysight.png')"
        style="margin: auto 2px; max-height: 36px"
        alt="キーサイト・テクノロジー"
      />
    </v-btn>
    <v-btn href="https://www.seikoh-giken.co.jp/" class="mr-1 px-0" tile text height="48px">
      <img
        :src="require('~/assets/img/JANOG55_seikoh_giken.png')"
        style="margin: auto 2px; max-height: 32px"
        alt="株式会社 精工技研"
      />
    </v-btn>
    <template v-if="isWide">
      <navigation-link
        v-for="nav in navigations"
        :key="nav.key"
        :to="nav.to"
        :always="nav.always"
        @click="nav.click"
      >
        <v-icon v-if="nav.icon">{{ nav.icon }}</v-icon>
        <div v-else>{{ nav.text }}</div>
      </navigation-link>
    </template>
    <template v-else>
      <v-menu open-on-hover offset-y>
        <template v-slot:activator="{ on }">
          <!-- divで囲まないと余白が崩れる -->
          <div>
            <v-app-bar-nav-icon
              :ripple="false"
              color="black"
              text
              tile
              v-on="on"
            />
          </div>
        </template>

        <v-list>
          <v-list-item
            v-for="nav in navigations"
            :key="nav.key"
            :to="nav.to"
            :always="nav.always"
            @click="nav.click"
          >
            <v-list-item-title>
              <v-icon v-if="nav.icon" color="black">{{ nav.icon }}</v-icon>
              <div v-else>{{ nav.text }}</div>
            </v-list-item-title>
          </v-list-item>
        </v-list>
      </v-menu>
    </template>
  </v-app-bar>
</template>
<script>
import { mapActions } from 'vuex'
import NavigationLink from '~/components/misc/NavigationLink'

export default {
  name: 'Navigation',
  components: {
    NavigationLink,
  },
  data() {
    return {
      isWide: true,
    }
  },
  computed: {
    navigations() {
      return this.navigationsBase
        .filter((nav) => (nav.if !== undefined ? nav.if : true))
        .map((nav) => {
          nav.key = nav.text || nav.icon
          nav.always = nav.always !== undefined ? nav.always : false
          nav.click = nav.click ? nav.click : () => {}
          return nav
        })
    },
    navigationsBase() {
      return [
        { to: '/', text: 'トップ' },
        { to: '/problems', text: '問題' },
        { to: '/issues', text: '質問', if: this.isNotAudience },
        { to: '/answers', text: '解答', if: this.isStaff },
        { to: '/summary', text: '状況', if: this.isStaff },
        { to: '/guide', text: 'ガイド' },
        { to: '/teams', text: 'ユーザ' },
        { to: '/settings', icon: 'mdi-cog-outline', if: this.isStaff },
        {
          to: '/login',
          text: 'ログイン',
          if: this.isNotLoggedIn,
          always: true,
        },
        {
          to: '/login',
          icon: 'mdi-exit-run',
          if: this.isLoggedIn,
          click: this.tryLogout,
        },
      ]
    },
    wideThreshold() {
      // 未ログインかプレイヤーなら後者
      return this.isStaff || this.isAudience ? 690 : 510
    },
  },
  watch: {
    isLoggedIn: {
      immediate: true,
      handler(value) {
        this.onResize()
      },
    },
  },
  beforeMount() {
    window.addEventListener('resize', this.onResize, { passive: true })
  },
  beforeDestroy() {
    if (typeof window !== 'undefined') {
      window.removeEventListener('resize', this.onResize, { passive: true })
    }
  },
  methods: {
    ...mapActions('session', ['logout']),

    async tryLogout() {
      if (await this.logout()) {
        this.notifySuccess({ message: 'ログアウトしました' })
        this.$router.push('/login')
      } else {
        this.notifyWarning({ message: 'ログインしていません' })
      }
    },
    onResize() {
      this.isWide = window.innerWidth >= this.wideThreshold
    },
  },
}
</script>
<style scoped lang="sass">
::v-deep
  .v-toolbar__content
    padding: 0px

  // よくわからんけどこれをつけるとアクティブリンクの色が直る
  .theme--light.v-btn--active::before
    opacity: 0
</style>
