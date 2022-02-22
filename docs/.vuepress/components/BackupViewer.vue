<script setup lang="ts">
import Modal from "./Modal.vue";
import { Buffer } from "buffer";
import { ref, reactive, onMounted } from "vue";
import bplistParser from "bplist-parser";
// import bplistCreator from "bplist-creator";

var fileReader;
const modalActive = ref(false);
const file = ref<File | Blob | null>();
const myObject: { title: string; data: [any?] } = reactive({
  title: "How to do lists in Vue",
  data: [],
});

const toggleModal = () => {
  modalActive.value = !modalActive.value;
};

async function handleFileRead($event: Event) {
  // Create the Uint8 Array from the uploaded file Array Buffer
  let arrayBuffer: Uint8Array = new Uint8Array(
    fileReader.result as ArrayBuffer
  );
  // Make it into a Buffer
  let buffer: Buffer = Buffer.from(arrayBuffer);

  let data = await bplistParser.parseFile(buffer);
  if (data) {
    console.log(data);
    myObject.data = data;
  }
}

function onFileChanged($event: Event) {
  const target = $event.target as HTMLInputElement;
  if (target && target.files) {
    file.value = target.files[0];

    fileReader.onloadend = handleFileRead;
    if (fileReader && file.value instanceof Blob) {
      fileReader.readAsArrayBuffer(file.value);
    }
  }
}

// lifecycle hooks
onMounted(() => {
  fileReader = new window.FileReader();

  console.log(`Mounted.`);
});
</script>

<template>
  <!-- Search Bar | Upload | Export -->
  <!-- The Library UI, with tabs to change lists -->
  <!-- Clicking into an anime pops up a modal for you to edit -->

  <input type="file" @change="onFileChanged($event)" />
  <Modal @close="toggleModal" :modalActive="modalActive">
    <div class="modal-content">
      <h1>This is a Modal Header</h1>
      <p>This is a modal message</p>
    </div>
  </Modal>
  <button @click="toggleModal" type="button">Open Modal</button>
  <div v-for="value in myObject.data[0]?.history" :key="value.title">
    <p>{{ value.title }}</p>
    <p>{{ value.source }}</p>
    <div v-if="value.image?.relative !== undefined">
      <img
        v-lazy="{
          src: value.image?.relative,
          error:
            'https://github.com/SuperMarcus/NineAnimator/blob/master/NineAnimator/Assets.xcassets/Artwork%20Load%20Failure.imageset/loading_failure.jpg?raw=true',
        }"
        height="400"
        width="250"
      />
    </div>

    <p>{{ value.link?.relative }}</p>

    <br />
    <br />
  </div>
</template>

<style scoped>
button {
  font-weight: bold;
}
</style>
