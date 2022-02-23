<script setup lang="ts">
// import Modal from "./Modal.vue";
import { Buffer } from "buffer";
import { ref, reactive, computed, onMounted } from "vue";
import bplistParser from "bplist-parser";
// import bplistCreator from "bplist-creator";

var fileReader;
// const modalActive = ref(false);
const file = ref<File | Blob | null>();
const backupData: { data: [any?] } = reactive({
  data: [],
});
const searchState = reactive({
  filteredData: [],
  query: "",
});
const hasSearchResults = computed(() => {
  return searchState.filteredData && searchState.query !== "";
});
const resultData = computed(() => {
  return hasSearchResults.value
    ? searchState.filteredData
    : backupData.data[0]?.history; // hard coding history for now
});

// const toggleModal = () => {
//   modalActive.value = !modalActive.value;
// };

async function handleFileRead($event: Event) {
  // Create the Uint8 Array from the uploaded file Array Buffer
  let arrayBuffer: Uint8Array = new Uint8Array(
    fileReader.result as ArrayBuffer
  );
  // Make it into a Buffer
  let buffer: Buffer = Buffer.from(arrayBuffer);

  try {
    let data = await bplistParser.parseFile(buffer);
    if (data) {
      console.info("[DEBUG]: ", new Date(), data);

      backupData.data = data;
    }
  } catch (error) {
    console.error("Failed to parse data, something went wrong.");
  }
}

function onChooseFile($event: Event) {
  document.getElementById("fileUpload")!.click();
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

function handleSearchInput($event: Event) {
  const target = $event.target as HTMLInputElement;
  const query = target.value.trim();

  // hard coding history for now
  const filteredData = backupData.data[0]?.history.filter((data) => {
    const { title, source } = data;
    return (
      title.toLowerCase().includes(query.toLowerCase()) ||
      source.toLowerCase().includes(query.toLowerCase())
    );
  });

  searchState.query = query;
  searchState.filteredData = filteredData;
}

// lifecycle hooks
onMounted(() => {
  fileReader = new window.FileReader();
});
</script>

<template>
  <!-- TODO: Search Bar | Upload | Export -->
  <!-- The Library UI, with tabs to change lists -->
  <!-- Clicking into an anime pops up a modal for you to edit -->
  <h2>
    <svg id="svg__gooey" xmlns="http://www.w3.org/2000/svg" version="1.1">
      <defs>
        <filter id="gooey">
          <feGaussianBlur in="SourceGraphic" stdDeviation="5" result="blur" />
          <feColorMatrix
            in="blur"
            type="matrix"
            values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 19 -9"
            result="highContrastGraphic"
          />
          <feComposite
            in="SourceGraphic"
            in2="highContrastGraphic"
            operator="atop"
          />
        </filter>
      </defs>
    </svg>

    <span id="svg-wrapper">
      <button id="gooey__button" @click="onChooseFile" filter="url(#gooey)">
        Upload
        <span class="bubbles">
          <span class="bubble"></span>
          <span class="bubble"></span>
          <span class="bubble"></span>
          <span class="bubble"></span>
          <span class="bubble"></span>
        </span>
      </button>
    </span>

    <input
      id="fileUpload"
      type="file"
      @change="onFileChanged($event)"
      accept=".naconfig"
    />
    a NineAnimator
    <code>.naConfig</code>
    backup
  </h2>
  <!-- Hardcoding history for now -->
  <div v-if="backupData.data.length > 0 && backupData.data[0]?.history">
    <h2>
      History | Exported on
      {{ backupData.data[0]?.exportedDate?.toDateString() }}
    </h2>
    <form
      class="search-box"
      role="search"
      :style="{
        display: 'block',
        marginRight: '19.2px',
      }"
    >
      <input
        type="text"
        placeholder="Type here"
        aria-label="Search"
        :style="{ width: '100%' }"
        @input="handleSearchInput"
      />
    </form>
    <div class="cards">
      <div
        class="card"
        v-for="(value, index) in resultData"
        :key="`${value.title}-${value.source}-${index}`"
      >
        <img
          v-if="value.image?.relative !== undefined"
          class="card__image"
          alt=""
          v-lazy="{
            src: value.image?.relative,
            loading:
              'https://c.tenor.com/RgF5keyruhcAAAAM/alex-geerken-geerken.gif',
            error:
              'https://9ani.app/static/resources/artwork_not_available.jpg',
          }"
        />
        <div class="card__overlay">
          <div class="card__header">
            <svg class="card__arc" xmlns="http://www.w3.org/2000/svg">
              <path>
                <animate
                  attributeName="d"
                  values="M 40 80 c 22 0 40 -22 40 -40 v 40 Z"
                />
              </path>
            </svg>
            <div class="card__header-text">
              <h3 class="card__title">{{ value.title }}</h3>
              <span class="card__status">{{ value.source }}</span>
            </div>
          </div>
          <a
            class="card__description"
            :href="value.link?.relative"
            target="_blank"
            rel="noreferrer noopener"
          >
            {{ value.link?.relative }}
          </a>
        </div>
      </div>
    </div>
  </div>
  <div v-else></div>
</template>

<style scoped>
@import "./BackupViewer.css";
</style>
