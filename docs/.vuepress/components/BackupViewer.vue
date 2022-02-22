<script setup lang="ts">
// import cloneDeep from "lodash/cloneDeep";
// import bplistCreator from "bplist-creator";
// import bPlistParser from "bplist-parser";
import { ref, onMounted } from "vue";

const file = ref<File | null>();
const form = ref<HTMLFormElement>();

function onFileChanged($event: Event) {
  const target = $event.target as HTMLInputElement;
  if (target && target.files) {
    file.value = target.files[0];
    console.log(file.value);
  }
}

async function saveImage() {
  if (file.value) {
    try {
      // save file.value
    } catch (error) {
      console.error(error);
      form.value?.reset();
      file.value = null;
    } finally {
    }
  }
}

// lifecycle hooks
onMounted(() => {
  console.log(`The initial count is ${file.value}.`);
});
</script>

<template>
  <!-- Search Bar | Upload | Export -->
  <!-- The Library UI, with tabs to change lists -->
  <!-- Clicking into an anime pops up a modal for you to edit -->

  <input type="file" @change="onFileChanged($event)" capture />
</template>

<style scoped>
button {
  font-weight: bold;
}
</style>
