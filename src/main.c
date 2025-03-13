/*

Device: STM32F103C8T6
Package: LQFP48
*/

#include <stdbool.h>
#include <init.h>

#include <stm32f10x_conf.h>

volatile bool tick = false;

void SysTick_Handler(void)
{
  tick = true;
}

int main(void)
{
  //turn on external crystal and use it
  RCC_HSEConfig(RCC_HSE_ON);
  while (!RCC_WaitForHSEStartUp());
  SystemCoreClockUpdate();
  InitGPIO();
  GPIOC->ODR &= ~(1 << 13);
  /* enable the main loop interrupt generation */
  SysTick_Config(SystemCoreClock / 10);

  /* Configure the SysTick handler priority */
  NVIC_SetPriority(SysTick_IRQn, 0x3);

  while (true)
  {
    if (tick)
    {
      tick = false;
      GPIOC->ODR ^= (1 << 13); // LED on Blue Pill board
    }
  };


}// end main

