// Register controllers from the importmap via controllers/**/*_controller,
// each loaded when an element first asks for it. The map controller pulls
// in MapLibre, so pages without a map never download it.
import { application } from "controllers/application"
import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
lazyLoadControllersFrom("controllers", application)
