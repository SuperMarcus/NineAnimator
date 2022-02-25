<script lang="ts">
import { defineComponent, PropType } from "vue";
import { notify } from "@kyvg/vue3-notification";
import { AnimeLink } from "./NineAnimatorBackup";

interface FormElements extends HTMLFormElement {
  animeTitle: HTMLInputElement;
  animeSource: HTMLInputElement;
  animeImage: HTMLInputElement;
  animeLink: HTMLInputElement;
}

export default defineComponent({
  name: "Modal",
  props: {
    index: Number,
    currentData: Object as PropType<AnimeLink>,
  },
  methods: {
    editCurrentData() {
      let formElement: FormElements = this.$refs.edit__form as FormElements;
      this.newCurrentData.title = formElement.animeTitle.value;
      this.newCurrentData.source = formElement.animeSource.value;
      this.newCurrentData.image.relative = formElement.animeImage.value;
      this.newCurrentData.link.relative = formElement.animeLink.value;

      this.$emit("update:currentData", this.newCurrentData);
      notify({
        type: "success",
        title: "🔵 Success: Backup Viewer",
        text: "Successfully edited the anime",
      });
    },
    close() {
      this.$emit("close");
    },
  },
  data() {
    return {
      newCurrentData: this.currentData!,
    };
  },
});
</script>

<template>
  <transition name="modal-fade">
    <div class="modal-backdrop">
      <div
        class="modal"
        role="dialog"
        aria-labelledby="modalTitle"
        aria-describedby="modalDescription"
      >
        <div class="modal-header" id="modalTitle">
          <slot name="header"><h2>Edit Anime</h2></slot>
          <button
            type="button"
            class="btn-close"
            @click="close"
            aria-label="Close modal"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="30"
              height="30"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="#2c3e50"
              fill="none"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path stroke="none" d="M0 0h24v24H0z" fill="none" />
              <circle cx="12" cy="12" r="9" />
              <path d="M10 10l4 4m0 -4l-4 4" />
            </svg>
          </button>
        </div>

        <section class="modal-body" id="modalDescription">
          <slot name="body">
            <form ref="edit__form">
              <div class="form__group field">
                <textarea
                  class="form__field"
                  name="animeTitle"
                  :value="this.newCurrentData?.title"
                />
                <label for="name" class="form__label">Title</label>
              </div>
              <div class="form__group field">
                <textarea
                  class="form__field"
                  :value="this.newCurrentData?.source"
                  name="animeSource"
                />
                <label for="name" class="form__label">Source</label>
              </div>
              <div class="form__group field">
                <textarea
                  class="form__field"
                  :value="this.newCurrentData?.image?.relative"
                  name="animeImage"
                />
                <label for="image" class="form__label">Image</label>
              </div>
              <div class="form__group field">
                <textarea
                  class="form__field"
                  :value="this.newCurrentData?.link?.relative"
                  name="animeLink"
                />
                <label for="link" class="form__label">Link</label>
              </div>
            </form>
          </slot>
        </section>

        <div class="modal-footer">
          <slot name="footer">
            <button id="footer-apply" type="button" @click="editCurrentData">
              Apply changes
            </button>
          </slot>
          <button
            id="footer-close"
            type="button"
            @click="close"
            aria-label="Close modal"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  </transition>
</template>

<style scoped>
h2 {
  border-bottom: none;
  padding: 0;
  margin: 0;
}
.modal-backdrop {
  position: fixed;
  top: 0;
  bottom: 0;
  left: 0;
  right: 0;
  background-color: #0000004d;
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 999;
}

.modal {
  border-radius: 15px;
  padding: 1rem;
  background: #fff;
  overflow-x: auto;
  display: flex;
  flex-direction: column;
  min-width: 70%;
  min-height: 50%;
}

.modal-header,
.modal-footer {
  display: flex;
}

.modal-header {
  padding-bottom: 15px;
  position: relative;
  border-bottom: 1px solid #eeeeee;
  justify-content: space-between;
}

.modal-footer {
  padding-top: 15px;
  border-top: 1px solid #eeeeee;
  flex-direction: row;
  justify-content: flex-end;
}

.modal-body {
  position: relative;
  padding: 20px 10px;
}

.btn-close {
  position: absolute;
  top: 0;
  right: 0;
  border: none;
  cursor: pointer;
  background: transparent;
}

button#footer-close,
button#footer-apply {
  border-radius: 5px;
  border: none;
  cursor: pointer;
  margin: 0.2rem 0.3rem;
  padding: 0.6rem;
  color: #fff;
}

button#footer-close {
  background-color: #ff605c;
}

button#footer-apply {
  background-color: #673bcc;
}

.modal-fade-enter,
.modal-fade-leave-to {
  opacity: 0;
}

.modal-fade-enter-active,
.modal-fade-leave-active {
  transition: opacity 0.5s ease;
}

.form__group {
  position: relative;
  padding: 15px 0 0;
  margin-top: 10px;
  width: 100%;
}
.form__field {
  font-family: inherit;
  width: 100%;
  border: 0;
  border-bottom: 2px solid #9b9b9b;
  outline: 0;
  font-size: 1.2rem;
  color: rgb(0, 0, 0);
  padding: 7px 0;
  background: transparent;
  transition: border-color 0.2s;
  resize: vertical;
  height: 1.3rem;
  min-height: 1.3rem;
  max-height: 4rem;
  overflow: hidden;
}
.form__field::value {
  color: transparent;
}
.form__field:value-shown ~ .form__label {
  font-size: 1.3rem;
  cursor: text;
  top: 20px;
}
.form__label {
  position: absolute;
  top: 0;
  display: block;
  transition: 0.2s;
  font-size: 1rem;
  color: #9b9b9b;
}
.form__field:focus {
  padding-bottom: 6px;
  font-weight: 700;
  border-width: 3px;
  border-image: linear-gradient(to right, #673bcc, #ec59d9);
  border-image-slice: 1;
}
.form__field:focus ~ .form__label {
  position: absolute;
  top: 0;
  display: block;
  transition: 0.2s;
  font-size: 1rem;
  color: #673bcc;
  font-weight: 700;
}
/* reset input */
.form__field:required,
.form__field:invalid {
  box-shadow: none;
}
</style>
