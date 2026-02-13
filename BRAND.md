# Version Lab Brand Guide

## Logo
- **File:** `app/assets/images/version-lab-icon.png`
- Use the logo mark in sidebars, favicons, and compact layouts
- Always display on a white or light background for contrast

## Colors

| Role       | Hex       | Usage                                              |
|------------|-----------|----------------------------------------------------|
| Primary    | `#CD0000` | Buttons, links, CTAs, active states, accent color  |
| Dark       | `#000000` | Navbar, sidebar, footer, headings, body text       |
| Light BG   | `#F5F5F5` | Page backgrounds, cards                            |
| White      | `#FFFFFF` | Card surfaces, topbar, input backgrounds           |
| Muted text | `#6c757d` | Secondary text, placeholders                       |

### Tints (derived from Primary)
| Name        | Hex       | Usage                          |
|-------------|-----------|--------------------------------|
| Primary-90  | `#B80000` | Hover / pressed state          |
| Primary-10  | `#FFF0F0` | Light accent backgrounds       |

## Typography
- **Headings:** System sans-serif stack (Bootstrap default), bold weight
- **Body:** System sans-serif stack, regular weight

## Bootstrap Overrides
Bootstrap's `$primary` is set to `#CD0000`. The `$dark` variable is set to `#000000`. All Bootstrap utilities (`btn-primary`, `text-primary`, `bg-primary`, `bg-dark`, etc.) reflect brand colors automatically.
