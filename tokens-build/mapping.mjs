export const CONTEXTS = {
  standard: {},
  light: { theme: 'light' },
  dark: { theme: 'dark' },
  lightIncreased: { theme: 'light', contrast: 'more' },
  darkIncreased: { theme: 'dark', contrast: 'more' },
  fine: { pointer: 'fine' },
  coarse: { pointer: 'coarse' },
  regular: { width: 'regular' },
  compact: { width: 'compact' },
};

export const PALETTE = [
  ['text', 'color-text'],
  ['textMuted', 'color-text-muted'],
  ['border', 'color-border'],
  ['inputBorder', 'color-input-border'],
  ['borderHover', 'color-border-hover'],
  ['control', 'color-control-hover'],
  ['error', 'color-error'],
  ['errorHover', 'color-error-hover'],
  ['background', 'color-bg'],
  ['backgroundDisabled', 'color-bg-disabled'],
  ['backgroundHover', 'color-bg-hover'],
  ['primary', 'color-primary'],
  ['onPrimary', 'color-primary-text'],
  ['secondaryBorder', 'color-secondary-border'],
  ['scrim', 'color-scrim'],
  ['shadow', 'color-shadow'],
  ['focus', 'color-border-focus'],
  ['primaryHover', 'color-primary-hover'],
  ['primarySoft', 'color-primary-soft'],
  ['errorSoft', 'color-error-soft'],
  ['inputBorderHover', 'color-input-border-hover'],
];

export const MIXES = [
  ['primaryHover', 'color-primary-hover', '{color.primary.default}'],
  ['primarySoft', 'color-primary-soft', '{color.primary.default}', '{color.bg.default}'],
  ['errorSoft', 'color-error-soft', '{color.error.default}', '{color.bg.default}'],
];

export const TYPOGRAPHY = [
  ['body', 'font-size'],
  ['small', 'font-size-small'],
  ['heading', 'font-size-heading'],
  ['title', 'font-size-title'],
];

export const STEPS = [
  ['headingStep', 'font-size-heading'],
  ['titleStep', 'font-size-title'],
];

export const SPACING = [
  ...Array.from({ length: 10 }, (_, index) => [`s${index + 1}`, `space-${index + 1}`]),
  ['gap', 'gap'],
  ['cardPadding', 'card-padding'],
];

export const RADII = [['control', 'radius']];

export const CONTROLS = [
  ['height', 'control-height'],
  ['iconButton', 'icon-button-size'],
  ['star', 'star-size'],
  ['optionImageWidth', 'option-image-width'],
];

export const SHADOW = 'shadow-raised';

export const ALIASES = [
  ['option-card-border', 'color-input-border'],
  ['option-card-border-hover', 'color-input-border-hover'],
  ['input-padding-block', 'space-4'],
  ['input-padding-inline', 'space-6'],
  ['color-input-border-strong', 'color-input-border', ['lightIncreased', 'darkIncreased']],
  ['color-input-border-strong-hover', 'color-input-border-hover', ['lightIncreased', 'darkIncreased']],
];
