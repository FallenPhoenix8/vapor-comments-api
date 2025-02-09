<script setup lang="ts">
import { ref } from "vue"
import useComments from "./components/util/UseComments.vue"
import Button from "./components/Button.vue"

const comments = ref<Comment[]>([])

function updateComments(newComments: Comment[]) {
  comments.value = newComments
  console.log(comments.value)
}
</script>

<template>
  <!-- <Utilities> -->
  <use-comments @update:comments="updateComments" />
  <!-- </Utilities> -->
  <!----->
  <!-- Content -->

  <div>it works</div>
  <Button>Click me</Button>
</template>
