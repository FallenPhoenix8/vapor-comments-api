<script setup lang="ts">
import { ref } from "vue"

const { onClick } = defineProps({
  onClick: Function,
})

const isActive = ref(false)

function setActiveTrue() {
  isActive.value = true
}

function setActiveFalse() {
  isActive.value = false
}
</script>
<template>
  <button
    class="btn"
    :class="{ active: isActive }"
    @mouseenter="setActiveTrue"
    @mouseleave="setActiveFalse"
    @focusin="setActiveTrue"
    @focusout="setActiveFalse"
    @click="onClick || function () {}"
  >
    <slot />
  </button>
</template>
