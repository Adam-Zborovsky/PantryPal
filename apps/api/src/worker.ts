import { Logger } from '@nestjs/common';

async function bootstrap() {
  const logger = new Logger('Worker');
  logger.log('PantryPal worker started; queue processing is configured when Redis is available.');
}

void bootstrap();
