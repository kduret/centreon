import axios from "axios";
import * as actions from "../actions/bamConfigurationActions";
import {
  put,
  takeLatest,
  takeEvery,
  all,
  fork,
  take,
  call
} from "redux-saga/effects";

export function* setBaConfiguration() {
  yield takeEvery(actions.BA_CONFIGURATION_CHANGED, setConfiguration);
}

function* setConfiguration({configuration}) {
  try {
    yield put({ type: actions.SET_BA_CONFIGURATION, configuration });
  } catch (err) {
    throw err;
  }
}