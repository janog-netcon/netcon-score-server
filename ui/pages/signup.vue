<template>
  <v-container justify-center fill-height>
    <v-form v-model="valid" @submit.prevent="submit">
      <v-text-field
        v-model="name"
        :rules="nameRules"
        label="ユーザ名"
        required
        autofocus
      >
      </v-text-field>

      <v-text-field
        v-model="organization"
        :rules="organizationRules"
        label="所属組織"
      >
      </v-text-field>

      <v-text-field
        v-model="password"
        :rules="passwordRules"
        :type="passwordVisible ? 'text' : 'password'"
        :append-icon="passwordVisible ? 'mdi-eye' : 'mdi-eye-off'"
        label="パスワード"
        required
        @click:append="passwordVisible = !passwordVisible"
      >
      </v-text-field>

      <v-text-field
        v-model="registrationCode"
        :rules="registrationCodeRules"
        :type="registrationCodeVisible ? 'text' : 'password'"
        :append-icon="registrationCodeVisible ? 'mdi-eye' : 'mdi-eye-off'"
        label="登録コード"
        required
        @click:append="registrationCodeVisible = !registrationCodeVisible"
      >
      </v-text-field>

      <v-btn
        :disabled="!valid"
        :loading="loading"
        type="submit"
        color="success"
        block
      >
        作成
      </v-btn>
    </v-form>
  </v-container>
</template>
<script>
import { mapActions } from 'vuex'

const EndPoint = 'sessions/signup'

export default {
  name: 'SigninPage',

  data() {
    return {
      valid: false,
      name: '',
      password: '',
      organization: '',
      passwordVisible: false,
      registrationCode: '',
      registrationCodeVisible: false,
      loading: false,

      // 鬱陶しいのでメッセージは出さない
      nameRules: [(v) => !!v || ''],
      // 空でも良い
      organizationRules: [() => true || ''],
      // TODO: 長さ制限ぐらいはつけるべき?
      passwordRules: [(v) => !!v || ''],
      registrationCodeRules: [(v) => !!v || ''],
    }
  },
  methods: {
    async submit() {
      this.loading = true

      const params = { name: this.name, password: this.password, organization: this.organization, registrationCode: this.registrationCode }

      const res = await this.$axios.post(EndPoint, params)

      switch (res.status) {
        case 201:
          this.notifySuccess({ message: '作成しました' })
          this.$router.push('/login')
          break
        case 400:
          this.notifyWarning({
            message: '作成に失敗しました\n解決しない場合は運営にお問い合わせください',
          })
          break
        case 403:
          this.notifyWarning({
            message: '登録コードが間違っています',
          })
          break
        case 409:
          // 実はnameだけでなく、numberがコンフリクトしている可能性もある
          this.notifyWarning({
            message: '既に存在するユーザ名です',
          })
          break
        default:
          this.notifyError({
            message: '予期せぬエラーが発生しました',
          })
      }

      this.loading = false
    }
  },
  head() {
    return {
      title: 'ログイン',
    }
  },
}
</script>
