import * as Turbo from '@hotwired/turbo'
import { Application } from '@hotwired/stimulus'
import * as ActiveStorage from '@rails/activestorage'
import 'trix'
import '@rails/actiontext'
import '@mux/mux-player'

import {
  HeliosPressBlocksController,
  HeliosPressTextBlockController,
  HeliosPressImageBlockController
} from 'helios/press'

import { HeliosVideoBlockController } from 'helios/videos'

Turbo.start()
ActiveStorage.start()

const application = Application.start()
application.register('helios-press-blocks', HeliosPressBlocksController)
application.register('helios-press-text-block', HeliosPressTextBlockController)
application.register('helios-press-image-block', HeliosPressImageBlockController)
application.register('helios-video-block', HeliosVideoBlockController)
