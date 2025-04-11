PROJ_NAME=main

	PROGRAM_VERSION := $(shell \
  if git diff-files --quiet; \
  then \
    git rev-parse --short=7 HEAD | tr -d '\n'; \
  else \
    git rev-parse --short=6 HEAD | tr -d '\n'; \
    echo -n '+'; \
  fi)


SRCS = src/main.c \
       system_stm32f10x.c\
       startup_stm32f10x_md.s\
       src/init.c

SRCS +=	Libraries/STM32F10x_StdPeriph_Driver/src/stm32f10x_gpio.c\
	Libraries/STM32F10x_StdPeriph_Driver/src/stm32f10x_rcc.c

CC=ccache arm-none-eabi-gcc
OBJCOPY=arm-none-eabi-objcopy

OBJDIR = build

# -g ist debug info im Code
CFLAGS += -Wall -Wno-missing-braces -std=c99 $(HWTYPE)
CFLAGS += -mthumb -mcpu=cortex-m3 -fsigned-char -ffunction-sections -mlittle-endian
#CFLAGS += -mfloat-abi=hard -mfpu=fpv4-sp-d16

CFLAGS += -mfpu=vfp
CFLAGS += -mfloat-abi=soft

#für das 103 Board
CFLAGS += -D USE_STDPERIPH_DRIVER=1 -D STM32F10X_MD -D HSE_VALUE=8000000

CFLAGS += -Isrc -I. -I Libraries/CMSIS/CM3/DeviceSupport/ST/STM32F10x -I Libraries/CMSIS/CM3/CoreSupport
CFLAGS += -I Libraries/STM32F10x_StdPeriph_Driver/inc/

CFLAGS += -DFW_VERS=\"$(PROGRAM_VERSION)\"

LDFLAGS = -Wl,-Map,$(OBJDIR)/$(PROJ_NAME).map -g 
LDFLAGS += -T stm32_flash.ld

LDFLAGS += -lc -lrdimon -lm 

OPENOCD= openocd

OOCD_INIT += -f interface/stlink-v2.cfg
OOCD_INIT += -f target/stm32f1x.cfg
OOCD_INIT += -c "adapter_khz 500"
OOCD_INIT += -c "transport select hla_swd"
OOCD_INIT += -c init
OOCD_INIT += -c "reset"
OOCD_INIT += -c "reset init"
OOCD_FLASH= -c "reset halt"
OOCD_FLASH += -c "targets"
OOCD_FLASH += -c "flash write_image erase $(OBJDIR)/$(PROJ_NAME).elf"
OOCD_FLASH += -c "verify_image $(OBJDIR)/$(PROJ_NAME).elf"
OOCD_FLASH += -c "reset run"
OOCD_FLASH += -c shutdown

GDBSERVER = arm-none-eabi-gdb

#OOCD_DEBUG += -c 
# gdb
#target remote 127.0.0.1:3333

#arm-none-eabi-gdb build/main.elf

OBJS := $(SRCS:.c=.o)
OBJS := $(OBJS:.s=.o)
OBJS := $(addprefix $(OBJDIR)/,$(OBJS))

all: $(OBJDIR)/$(PROJ_NAME).elf $(OBJDIR)/$(PROJ_NAME).hex $(OBJDIR)/$(PROJ_NAME).bin
	arm-none-eabi-size $(OBJDIR)/$(PROJ_NAME).elf
	echo "firmware version is \""$(PROGRAM_VERSION)"\""

$(OBJDIR)/%.elf: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

%.hex: %.elf
	$(OBJCOPY) -O ihex $^ $@

%.bin: %.elf
	$(OBJCOPY) -O binary $^ $@

$(OBJDIR)/%.o: %.c
	mkdir -p $(dir $@)
	$(CC) -c $(CFLAGS) -o $@ $^

$(OBJDIR)/%.o: %.s
	$(CC) -c $(CFLAGS) -o $@ $^

$(OBJDIR):
	mkdir -p $@

clean:
	rm -f $(OBJDIR)/$(PROJ_NAME).elf
	rm -f $(OBJDIR)/$(PROJ_NAME).hex
	rm -f $(OBJDIR)/$(PROJ_NAME).bin
	rm -f $(OBJDIR)/$(PROJ_NAME).map
	find $(OBJDIR) -type f -name '*.o' -print0 | xargs -0 -r rm

beauti:
	astyle --style=allman --indent=spaces=2 --indent-switches --pad-oper --pad-header --unpad-paren --align-pointer=name --align-reference=name --add-brackets --min-conditional-indent=0 --keep-one-line-statements --convert-tabs --max-code-length=79 --break-after-logical --lineend=linux src/*.c
	astyle --style=allman --indent=spaces=2 --indent-switches --pad-oper --pad-header --unpad-paren --align-pointer=name --align-reference=name --add-brackets --min-conditional-indent=0 --keep-one-line-statements --convert-tabs --max-code-length=79 --break-after-logical --lineend=linux src/*.h

#program: $(OBJDIR)/$(PROJ_NAME).elf
#	openocd-0.6.1 -f program.cfg
#

#flash: $(OBJDIR)/$(PROJ_NAME).bin
#	st-flash write $(OBJDIR)/$(PROJ_NAME).bin 0x8000000

flash: $(OBJDIR)/$(PROJ_NAME).elf
	$(OPENOCD) $(OOCD_INIT) $(OOCD_FLASH)

debug:
	echo "file $(OBJDIR)/$(PROJ_NAME).elf\ntarget remote localhost:3333\nbreak main\n" > .gdbinit
	gnome-terminal --command="$(OPENOCD) $(OOCD_INIT) $(OOCD_DEBUG)" &
	gnome-terminal --command="$(GDBSERVER) $(OBJDIR)/$(PROJ_NAME).elf" &

#debug: flash
#	echo -e "file $(BUILD)/$(NAME).elf\ntarget remote localhost:2331\nbreak main\nmon semihosting enable\nmon semihosting ThumbSWI 0xAB\n" > .gdbinit
#	$(TERMINAL) "$(JLINKGDB) $(JLINK_OPTIONS) -port 2331" &
#	sleep 1
#	$(TERMINAL) "telnet localhost 2333" &
#	$(TERMINAL) "$(TARGET_GDB) $(BUILD)/$(NAME).elf"

	#& && arm-none-eabi-gdb build/main.elf

# Dependdencies
$(OBJDIR)/$(PROJ_NAME).elf: $(OBJS) | $(OBJDIR)
